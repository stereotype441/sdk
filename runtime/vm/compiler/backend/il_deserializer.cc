// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#if !defined(DART_PRECOMPILED_RUNTIME)

#include "vm/compiler/backend/il_deserializer.h"

#include "vm/compiler/backend/il_serializer.h"
#include "vm/compiler/jit/compiler.h"
#include "vm/flags.h"
#include "vm/os.h"

namespace dart {

DEFINE_FLAG(bool,
            trace_round_trip_serialization,
            false,
            "Print out tracing information during round trip serialization.");
DEFINE_FLAG(bool,
            print_json_round_trip_results,
            false,
            "Print out results of each round trip serialization in JSON form.");

// Contains the contents of a single round-trip result.
struct RoundTripResults : public ValueObject {
  explicit RoundTripResults(Zone* zone, const Function& func)
      : function(func), unhandled(zone, 2) {}

  // The function for which a flow graph was being parsed.
  const Function& function;
  // Whether the round trip succeeded.
  bool success = false;
  // An array of unhandled instructions found in the flow graph.
  GrowableArray<Instruction*> unhandled;
  // The serialized form of the flow graph, if computed.
  SExpression* serialized = nullptr;
  // The error information from the deserializer, if an error occurred.
  const char* error_message = nullptr;
  SExpression* error_sexp = nullptr;
};

static void PrintRoundTripResults(Zone* zone, const RoundTripResults& results) {
  THR_Print("Results of round trip serialization: {\"function\":\"%s\"",
            results.function.ToFullyQualifiedCString());
  THR_Print(",\"success\":%s", results.success ? "true" : "false");
  if (!results.unhandled.is_empty()) {
    CStringMap<intptr_t> count_map(zone);
    for (auto inst : results.unhandled) {
      auto const name = inst->DebugName();
      auto const old_count = count_map.LookupValue(name);
      count_map.Update({name, old_count + 1});
    }
    THR_Print(",\"unhandled\":{");
    auto count_it = count_map.GetIterator();
    auto first_kv = count_it.Next();
    THR_Print("\"%s\":%" Pd "", first_kv->key, first_kv->value);
    while (auto kv = count_it.Next()) {
      THR_Print(",\"%s\":%" Pd "", kv->key, kv->value);
    }
    THR_Print("}");
  }
  if (results.serialized != nullptr) {
    TextBuffer buf(1000);
    results.serialized->SerializeTo(zone, &buf, "");
    // Now that the S-expression has been serialized to the TextBuffer, we now
    // want to take that version and escape it since we will use it as the
    // contents of a JSON string. Thankfully, escaping can be done via
    // TextBuffer::AddEscapedString, so we steal the current buffer and then
    // re-print it in escaped form into the now-cleared buffer.
    char* const unescaped_sexp = buf.Steal();
    buf.AddEscapedString(unescaped_sexp);
    free(unescaped_sexp);
    THR_Print(",\"serialized\":\"%s\"", buf.buf());
  }
  if (results.error_message != nullptr) {
    TextBuffer buf(1000);
    ASSERT(results.error_sexp != nullptr);
    // Same serialized S-expression juggling as in the results.serialized case.
    // We also escape the error message, in case it included quotes.
    buf.AddEscapedString(results.error_message);
    char* const escaped_message = buf.Steal();
    results.error_sexp->SerializeTo(zone, &buf, "");
    char* const unescaped_sexp = buf.Steal();
    buf.AddEscapedString(unescaped_sexp);
    free(unescaped_sexp);
    THR_Print(",\"error\":{\"message\":\"%s\",\"expression\":\"%s\"}",
              escaped_message, buf.buf());
    free(escaped_message);
  }
  THR_Print("}\n");
}

void FlowGraphDeserializer::RoundTripSerialization(CompilerPassState* state) {
  auto const flow_graph = state->flow_graph;

  // The deserialized flow graph must be in the same zone as the original flow
  // graph, to ensure it has the right lifetime. Thus, we leave an explicit
  // use of [flow_graph->zone()] in the deserializer construction.
  //
  // Otherwise, it would be nice to use a StackZone to limit the lifetime of the
  // serialized form (and other values created with this [zone] variable), since
  // it only needs to live for the dynamic extent of this method.
  //
  // However, creating a StackZone for it also changes the zone associated with
  // the thread. Also, some parts of the VM used in later updates to the
  // deserializer implicitly pick up the zone to use either from a passed-in
  // thread or the current thread instead of taking an explicit zone.
  //
  // For now, just serialize into the same zone as the original flow graph, and
  // we can revisit this if this causes a performance issue or if we can ensure
  // that those VM parts mentioned can be passed an explicit zone.
  Zone* const zone = flow_graph->zone();

  // Final flow graph, if we successfully serialize and deserialize.
  FlowGraph* new_graph = nullptr;

  // Stored information for printing results if requested.
  RoundTripResults results(zone, flow_graph->function());

  FlowGraphDeserializer::AllUnhandledInstructions(flow_graph,
                                                  &results.unhandled);
  if (results.unhandled.is_empty()) {
    results.serialized = FlowGraphSerializer::SerializeToSExp(zone, flow_graph);

    if (FLAG_trace_round_trip_serialization && results.serialized != nullptr) {
      TextBuffer buf(1000);
      results.serialized->SerializeTo(zone, &buf, "");
      THR_Print("Serialized flow graph:\n%s\n", buf.buf());
    }

    // For the deserializer, use the thread from the compiler pass and zone
    // associated with the existing flow graph to make sure the new flow graph
    // has the right lifetime.
    FlowGraphDeserializer d(state->thread, flow_graph->zone(),
                            results.serialized, &flow_graph->parsed_function());
    new_graph = d.ParseFlowGraph();
    if (new_graph == nullptr) {
      ASSERT(d.error_message() != nullptr && d.error_sexp() != nullptr);
      if (FLAG_trace_round_trip_serialization) {
        THR_Print("Failure during deserialization: %s\n", d.error_message());
        THR_Print("At S-expression %s\n", d.error_sexp()->ToCString(zone));
      }
      results.error_message = d.error_message();
      results.error_sexp = d.error_sexp();
    } else {
      if (FLAG_trace_round_trip_serialization) {
        THR_Print("Successfully deserialized graph for %s\n",
                  results.serialized->AsList()->At(0)->AsSymbol()->value());
      }
      results.success = true;
    }
  } else if (FLAG_trace_round_trip_serialization) {
    THR_Print("Cannot serialize graph due to instruction: %s\n",
              results.unhandled.At(0)->DebugName());
  }

  if (FLAG_print_json_round_trip_results) PrintRoundTripResults(zone, results);

  if (new_graph != nullptr) state->flow_graph = new_graph;
}

#define HANDLED_CASE(name)                                                     \
  if (inst->Is##name()) return true;
bool FlowGraphDeserializer::IsHandledInstruction(Instruction* inst) {
  if (auto const const_inst = inst->AsConstant()) {
    return IsHandledConstant(const_inst->value());
  }
  FOR_EACH_HANDLED_BLOCK_TYPE_IN_DESERIALIZER(HANDLED_CASE)
  FOR_EACH_HANDLED_INSTRUCTION_IN_DESERIALIZER(HANDLED_CASE)
  return false;
}
#undef HANDLED_CASE

void FlowGraphDeserializer::AllUnhandledInstructions(
    const FlowGraph* graph,
    GrowableArray<Instruction*>* unhandled) {
  ASSERT(graph != nullptr);
  ASSERT(unhandled != nullptr);
  for (auto block_it = graph->reverse_postorder_iterator(); !block_it.Done();
       block_it.Advance()) {
    auto const entry = block_it.Current();
    if (!IsHandledInstruction(entry)) unhandled->Add(entry);
    // Don't check the Phi definitions in JoinEntrys, as those are now handled
    // and also parsed differently from other definitions.
    if (auto const def_block = entry->AsBlockEntryWithInitialDefs()) {
      auto const defs = def_block->initial_definitions();
      for (intptr_t i = 0; i < defs->length(); i++) {
        auto const current = defs->At(i);
        if (!IsHandledInstruction(current)) unhandled->Add(current);
      }
    }
    for (ForwardInstructionIterator it(entry); !it.Done(); it.Advance()) {
      auto current = it.Current();
      // We handle branches, so we need to check the comparison instruction.
      if (current->IsBranch()) current = current->AsBranch()->comparison();
      if (!IsHandledInstruction(current)) unhandled->Add(current);
    }
  }
}

// Keep in sync with work in ParseDartValue. Right now, this is just a shallow
// check, not a deep one.
bool FlowGraphDeserializer::IsHandledConstant(const Object& obj) {
  if (obj.IsArray()) return Array::Cast(obj).IsImmutable();
  return obj.IsNull() || obj.IsClass() || obj.IsFunction() || obj.IsField() ||
         obj.IsInstance();
}

SExpression* FlowGraphDeserializer::Retrieve(SExpList* list, intptr_t index) {
  if (list == nullptr) return nullptr;
  if (list->Length() <= index) {
    StoreError(list, "expected at least %" Pd " element(s) in list", index + 1);
    return nullptr;
  }
  auto const elem = list->At(index);
  if (elem == nullptr) {
    StoreError(list, "null value at index %" Pd "", index);
  }
  return elem;
}

SExpression* FlowGraphDeserializer::Retrieve(SExpList* list, const char* key) {
  if (list == nullptr) return nullptr;
  if (!list->ExtraHasKey(key)) {
    StoreError(list, "expected an extra info entry for key %s", key);
    return nullptr;
  }
  auto const elem = list->ExtraLookupValue(key);
  if (elem == nullptr) {
    StoreError(list, "null value for key %s", key);
  }
  return elem;
}

FlowGraph* FlowGraphDeserializer::ParseFlowGraph() {
  auto const root = CheckTaggedList(root_sexp_, "FlowGraph");
  if (root == nullptr) return nullptr;

  intptr_t deopt_id = DeoptId::kNone;
  if (auto const deopt_id_sexp =
          CheckInteger(root->ExtraLookupValue("deopt_id"))) {
    deopt_id = deopt_id_sexp->value();
  }
  EntryInfo common_info = {0, kInvalidTryIndex, deopt_id};

  auto const graph = DeserializeGraphEntry(root, common_info);

  PrologueInfo pi(-1, -1);
  flow_graph_ = new (zone()) FlowGraph(*parsed_function_, graph, 0, pi);
  flow_graph_->CreateCommonConstants();

  intptr_t pos = 2;
  if (auto const pool = CheckTaggedList(Retrieve(root, pos), "Constants")) {
    if (!ParseConstantPool(pool)) return nullptr;
    pos++;
  }

  // The deopt environment for the graph entry may use entries from the
  // constant pool, so that must be parsed first.
  if (auto const env_sexp = CheckList(root->ExtraLookupValue("env"))) {
    auto const env = ParseEnvironment(env_sexp);
    if (env == nullptr) return nullptr;
    env->DeepCopyTo(zone(), graph);
  }

  auto const entries_sexp = CheckTaggedList(Retrieve(root, pos), "Entries");
  if (!ParseEntries(entries_sexp)) return nullptr;
  pos++;

  // Now prime the block worklist with entries. We keep the block worklist
  // in reverse order so that we can just pop the next block for content
  // parsing off the end.
  BlockWorklist block_worklist(zone(), entries_sexp->Length() - 1);

  const auto& indirect_entries = graph->indirect_entries();
  for (auto indirect_entry : indirect_entries) {
    block_worklist.Add(indirect_entry->block_id());
  }

  const auto& catch_entries = graph->catch_entries();
  for (auto catch_entry : catch_entries) {
    block_worklist.Add(catch_entry->block_id());
  }

  if (auto const osr_entry = graph->osr_entry()) {
    block_worklist.Add(osr_entry->block_id());
  }
  if (auto const unchecked_entry = graph->unchecked_entry()) {
    block_worklist.Add(unchecked_entry->block_id());
  }
  if (auto const normal_entry = graph->normal_entry()) {
    block_worklist.Add(normal_entry->block_id());
  }

  // The graph entry doesn't push any arguments onto the stack. Adding a
  // pushed_stack_map_ entry for it allows us to unify how function entries
  // are handled vs. other types of blocks with regards to incoming pushed
  // argument stacks.
  auto const empty_stack = new (zone()) PushStack(zone(), 0);
  pushed_stack_map_.Insert(0, empty_stack);

  if (!ParseBlocks(root, pos, &block_worklist)) return nullptr;

  // Before we return the new graph, make sure all definitions were found for
  // all pending values.
  if (values_map_.Length() > 0) {
    auto it = values_map_.GetIterator();
    auto const kv = it.Next();
    // TODO(sstrickl): This assumes SSA variables.
    auto const sym =
        new (zone()) SExpSymbol(OS::SCreate(zone(), "v%" Pd "", kv->key));
    StoreError(sym, "no definition found for variable index in flow graph");
    return nullptr;
  }

  flow_graph_->set_max_block_id(max_block_id_);
  flow_graph_->set_current_ssa_temp_index(max_ssa_index_ + 1);
  // Now that the deserializer has finished re-creating all the blocks in the
  // flow graph, the blocks must be rediscovered. In addition, if ComputeSSA
  // has already been run, dominators must be recomputed as well.
  flow_graph_->DiscoverBlocks();
  // Currently we only handle SSA graphs, so always do this.
  GrowableArray<BitVector*> dominance_frontier;
  flow_graph_->ComputeDominators(&dominance_frontier);

  return flow_graph_;
}

bool FlowGraphDeserializer::ParseConstantPool(SExpList* pool) {
  ASSERT(flow_graph_ != nullptr);
  if (pool == nullptr) return false;
  // Definitions in the constant pool may refer to later definitions. However,
  // there should be no cycles possible between constant objects, so using a
  // worklist algorithm we should always be able to make progress.
  // Since we will not be adding new definitions, we make the initial size of
  // the worklist the number of definitions in the constant pool.
  GrowableArray<SExpList*> worklist(zone(), pool->Length() - 1);
  // We keep old_worklist in reverse order so that we can just RemoveLast
  // to get elements in their original order.
  for (intptr_t i = pool->Length() - 1; i > 0; i--) {
    const auto def_sexp = CheckTaggedList(pool->At(i), "def");
    if (def_sexp == nullptr) return false;
    worklist.Add(def_sexp);
  }
  while (true) {
    const intptr_t worklist_len = worklist.length();
    GrowableArray<SExpList*> parse_failures(zone(), worklist_len);
    while (!worklist.is_empty()) {
      const auto def_sexp = worklist.RemoveLast();
      auto& obj = Object::ZoneHandle(zone());
      if (!ParseDartValue(Retrieve(def_sexp, 2), &obj)) {
        parse_failures.Add(def_sexp);
        continue;
      }
      ConstantInstr* def = flow_graph_->GetConstant(obj);
      if (!ParseDefinitionWithParsedBody(def_sexp, def)) return false;
    }
    if (parse_failures.is_empty()) break;
    // We've gone through the whole worklist without success, so return
    // the last error we encountered.
    if (parse_failures.length() == worklist_len) return false;
    // worklist was added to in order, so we need to reverse its contents
    // when we add them to old_worklist.
    while (!parse_failures.is_empty()) {
      worklist.Add(parse_failures.RemoveLast());
    }
  }
  return true;
}

bool FlowGraphDeserializer::ParseEntries(SExpList* list) {
  ASSERT(flow_graph_ != nullptr);
  if (list == nullptr) return false;
  for (intptr_t i = 1; i < list->Length(); i++) {
    const auto entry = CheckTaggedList(Retrieve(list, i));
    if (entry == nullptr) return false;
    intptr_t block_id;
    if (!ParseBlockId(CheckSymbol(Retrieve(entry, 1)), &block_id)) {
      return false;
    }
    if (block_map_.LookupValue(block_id) != nullptr) {
      StoreError(entry->At(1), "multiple entries for block found");
      return false;
    }
    const auto tag = entry->At(0)->AsSymbol();
    if (ParseBlockHeader(entry, block_id, tag) == nullptr) return false;
  }
  return true;
}

bool FlowGraphDeserializer::ParseBlocks(SExpList* list,
                                        intptr_t pos,
                                        BlockWorklist* worklist) {
  // First, ensure that all the block headers have been parsed. Set up a
  // map from block IDs to S-expressions and the max_block_id while we're at it.
  IntMap<SExpList*> block_sexp_map(zone());
  for (intptr_t i = pos, n = list->Length(); i < n; i++) {
    auto const block_sexp = CheckTaggedList(Retrieve(list, i), "Block");
    intptr_t block_id;
    if (!ParseBlockId(CheckSymbol(Retrieve(block_sexp, 1)), &block_id)) {
      return false;
    }
    if (block_sexp_map.LookupValue(block_id) != nullptr) {
      StoreError(block_sexp->At(1), "multiple definitions of block found");
      return false;
    }
    block_sexp_map.Insert(block_id, block_sexp);
    auto const type_tag =
        CheckSymbol(block_sexp->ExtraLookupValue("block_type"));
    // Entry block headers are already parsed, but others aren't.
    if (block_map_.LookupValue(block_id) == nullptr) {
      if (ParseBlockHeader(block_sexp, block_id, type_tag) == nullptr) {
        return false;
      }
    }
    if (max_block_id_ < block_id) max_block_id_ = block_id;
  }

  // Now start parsing the contents of blocks from the worklist. We use an
  // IntMap to keep track of what blocks have already been fully parsed.
  IntMap<bool> fully_parsed_block_map(zone());
  while (!worklist->is_empty()) {
    auto const block_id = worklist->RemoveLast();

    // If we've already encountered this block, skip it.
    if (fully_parsed_block_map.LookupValue(block_id)) continue;

    auto const block_sexp = block_sexp_map.LookupValue(block_id);
    ASSERT(block_sexp != nullptr);

    // Copy the pushed argument stack of the predecessor to begin the stack for
    // this block. This is safe due to the worklist algorithm, since one
    // predecessor has already been added when this block is first reached.
    //
    // For JoinEntry blocks, since the worklist algorithm is a depth-first
    // search, we may not see all possible predecessors before the JoinEntry
    // is parsed. To ensure consistency between predecessor stacks, we check
    // the consistency in ParseBlockContents when updating predecessor
    // information.
    current_block_ = block_map_.LookupValue(block_id);
    ASSERT(current_block_ != nullptr);
    ASSERT(current_block_->PredecessorCount() > 0);
    auto const pred_id = current_block_->PredecessorAt(0)->block_id();
    auto const pred_stack = pushed_stack_map_.LookupValue(pred_id);
    ASSERT(pred_stack != nullptr);
    auto const new_stack = new (zone()) PushStack(zone(), pred_stack->length());
    new_stack->AddArray(*pred_stack);
    pushed_stack_map_.Insert(block_id, new_stack);

    if (!ParseBlockContents(block_sexp, worklist)) return false;

    // Mark this block as done.
    fully_parsed_block_map.Insert(block_id, true);
  }

  // Double-check that all blocks were reached by the worklist algorithm.
  auto it = block_sexp_map.GetIterator();
  while (auto kv = it.Next()) {
    if (!fully_parsed_block_map.LookupValue(kv->key)) {
      StoreError(kv->value, "block unreachable in flow graph");
      return false;
    }
  }

  return true;
}

bool FlowGraphDeserializer::ParseInitialDefinitions(SExpList* list) {
  ASSERT(current_block_ != nullptr);
  ASSERT(current_block_->IsBlockEntryWithInitialDefs());
  auto const block = current_block_->AsBlockEntryWithInitialDefs();
  if (list == nullptr) return false;
  for (intptr_t i = 2; i < list->Length(); i++) {
    const auto def_sexp = CheckTaggedList(Retrieve(list, i), "def");
    const auto def = ParseDefinition(def_sexp);
    if (def == nullptr) return false;
    flow_graph_->AddToInitialDefinitions(block, def);
  }
  return true;
}

BlockEntryInstr* FlowGraphDeserializer::ParseBlockHeader(SExpList* list,
                                                         intptr_t block_id,
                                                         SExpSymbol* tag) {
  ASSERT(flow_graph_ != nullptr);
  // We should only parse block headers once.
  ASSERT(block_map_.LookupValue(block_id) == nullptr);
  if (list == nullptr) return nullptr;

#if defined(DEBUG)
  intptr_t parsed_block_id;
  auto const id_sexp = CheckSymbol(Retrieve(list, 1));
  if (!ParseBlockId(id_sexp, &parsed_block_id)) return nullptr;
  ASSERT(block_id == parsed_block_id);
#endif

  auto const kind = FlowGraphSerializer::BlockEntryTagToKind(tag);

  intptr_t deopt_id = DeoptId::kNone;
  if (auto const deopt_int = CheckInteger(list->ExtraLookupValue("deopt_id"))) {
    deopt_id = deopt_int->value();
  }
  intptr_t try_index = kInvalidTryIndex;
  if (auto const try_int = CheckInteger(list->ExtraLookupValue("try_index"))) {
    try_index = try_int->value();
  }

  BlockEntryInstr* block = nullptr;
  EntryInfo common_info = {block_id, try_index, deopt_id};
  switch (kind) {
    case FlowGraphSerializer::kTarget:
      block = DeserializeTargetEntry(list, common_info);
      break;
    case FlowGraphSerializer::kNormal:
      block = DeserializeFunctionEntry(list, common_info);
      if (block != nullptr) {
        auto const graph = flow_graph_->graph_entry();
        graph->set_normal_entry(block->AsFunctionEntry());
      }
      break;
    case FlowGraphSerializer::kUnchecked: {
      block = DeserializeFunctionEntry(list, common_info);
      if (block != nullptr) {
        auto const graph = flow_graph_->graph_entry();
        graph->set_unchecked_entry(block->AsFunctionEntry());
      }
      break;
    }
    case FlowGraphSerializer::kJoin:
      block = DeserializeJoinEntry(list, common_info);
      break;
    case FlowGraphSerializer::kInvalid:
      StoreError(tag, "invalid block entry tag");
      return nullptr;
    default:
      StoreError(tag, "unhandled block type");
      return nullptr;
  }
  if (block == nullptr) return nullptr;

  block_map_.Insert(block_id, block);
  return block;
}

bool FlowGraphDeserializer::ParsePhis(SExpList* list) {
  ASSERT(current_block_ != nullptr && current_block_->IsJoinEntry());
  auto const join = current_block_->AsJoinEntry();
  const intptr_t start_pos = 2;
  auto const end_pos = SkipPhis(list);
  if (end_pos < start_pos) return false;

  for (intptr_t i = start_pos; i < end_pos; i++) {
    auto const def_sexp = CheckTaggedList(Retrieve(list, i), "def");
    auto const phi_sexp = CheckTaggedList(Retrieve(def_sexp, 2), "Phi");
    // SkipPhis should already have checked which instructions, if any,
    // are Phi definitions.
    ASSERT(phi_sexp != nullptr);

    // This is a generalization of FlowGraph::AddPhi where we let ParseValue
    // create the values (as they may contain type information).
    auto const phi = new (zone()) PhiInstr(join, phi_sexp->Length() - 1);
    phi->mark_alive();
    for (intptr_t i = 0, n = phi_sexp->Length() - 1; i < n; i++) {
      auto const val = ParseValue(Retrieve(phi_sexp, i + 1));
      if (val == nullptr) return false;
      phi->SetInputAt(i, val);
      val->definition()->AddInputUse(val);
    }
    join->InsertPhi(phi);

    if (!ParseDefinitionWithParsedBody(def_sexp, phi)) return false;
  }

  return true;
}

intptr_t FlowGraphDeserializer::SkipPhis(SExpList* list) {
  // All blocks are S-exps of the form (Block B# inst...), so skip the first
  // two entries and then skip any Phi definitions.
  for (intptr_t i = 2, n = list->Length(); i < n; i++) {
    auto const def_sexp = CheckTaggedList(Retrieve(list, i), "def");
    if (def_sexp == nullptr) return i;
    auto const phi_sexp = CheckTaggedList(Retrieve(def_sexp, 2), "Phi");
    if (phi_sexp == nullptr) return i;
  }

  StoreError(list, "block is empty or contains only Phi definitions");
  return -1;
}

bool FlowGraphDeserializer::ParseBlockContents(SExpList* list,
                                               BlockWorklist* worklist) {
  ASSERT(current_block_ != nullptr);
  auto const curr_stack =
      pushed_stack_map_.LookupValue(current_block_->block_id());
  ASSERT(curr_stack != nullptr);

  // Parse any Phi definitions now before parsing the block environment.
  if (current_block_->IsJoinEntry()) {
    if (!ParsePhis(list)) return false;
  }

  // For blocks with initial definitions or phi definitions, this needs to be
  // done after those are parsed. In addition, block environments can also use
  // definitions from dominating blocks, so we need the contents of dominating
  // blocks to first be parsed.
  //
  // However, we must parse the environment before parsing any instructions
  // in the body of the block to ensure we don't mistakenly allow local
  // definitions to appear in the environment.
  if (auto const env_sexp = CheckList(list->ExtraLookupValue("env"))) {
    auto const env = ParseEnvironment(env_sexp);
    if (env == nullptr) return false;
    env->DeepCopyTo(zone(), current_block_);
  }

  auto const pos = SkipPhis(list);
  if (pos < 2) return false;
  Instruction* last_inst = current_block_;
  for (intptr_t i = pos, n = list->Length(); i < n; i++) {
    auto const entry = CheckTaggedList(Retrieve(list, i));
    if (entry == nullptr) return false;
    Instruction* inst = nullptr;
    if (strcmp(entry->At(0)->AsSymbol()->value(), "def") == 0) {
      inst = ParseDefinition(entry);
    } else {
      inst = ParseInstruction(entry);
    }
    if (inst == nullptr) return false;
    last_inst = last_inst->AppendInstruction(inst);
  }

  ASSERT(last_inst != nullptr && last_inst != current_block_);
  if (last_inst->SuccessorCount() > 0) {
    for (intptr_t i = last_inst->SuccessorCount() - 1; i >= 0; i--) {
      auto const succ_block = last_inst->SuccessorAt(i);
      // Check and make sure the stack we have is consistent with stacks
      // from other predecessors.
      if (!AreStacksConsistent(list, curr_stack, succ_block)) return false;
      succ_block->AddPredecessor(current_block_);
      worklist->Add(succ_block->block_id());
    }
  }

  return true;
}

bool FlowGraphDeserializer::ParseDefinitionWithParsedBody(SExpList* list,
                                                          Definition* def) {
  intptr_t index;
  auto const name_sexp = CheckSymbol(Retrieve(list, 1));
  if (name_sexp == nullptr) return false;

  if (ParseSSATemp(name_sexp, &index)) {
    if (definition_map_.HasKey(index)) {
      StoreError(list, "multiple definitions for the same SSA index");
      return false;
    }
    def->set_ssa_temp_index(index);
    if (index > max_ssa_index_) max_ssa_index_ = index;
  } else {
    // TODO(sstrickl): Add temp support for non-SSA computed graphs.
    StoreError(list, "unhandled name for definition");
    return false;
  }

  if (auto const type_sexp =
          CheckTaggedList(list->ExtraLookupValue("type"), "CompileType")) {
    CompileType* typ = ParseCompileType(type_sexp);
    if (typ == nullptr) return false;
    def->UpdateType(*typ);
  }

  definition_map_.Insert(index, def);
  FixPendingValues(index, def);
  return true;
}

Definition* FlowGraphDeserializer::ParseDefinition(SExpList* list) {
  auto const inst_sexp = CheckTaggedList(Retrieve(list, 2));
  Instruction* const inst = ParseInstruction(inst_sexp);
  if (inst == nullptr) return nullptr;
  if (auto const def = inst->AsDefinition()) {
    if (!ParseDefinitionWithParsedBody(list, def)) return nullptr;
    return def;
  } else {
    StoreError(list, "instruction cannot be body of definition");
    return nullptr;
  }
}

Instruction* FlowGraphDeserializer::ParseInstruction(SExpList* list) {
  if (list == nullptr) return nullptr;
  auto const tag = list->At(0)->AsSymbol();

  intptr_t deopt_id = DeoptId::kNone;
  if (auto const deopt_int = CheckInteger(list->ExtraLookupValue("deopt_id"))) {
    deopt_id = deopt_int->value();
  }
  InstrInfo common_info = {deopt_id, TokenPosition::kNoSource};

  // Parse the environment before handling the instruction, as we may have
  // references to PushArguments and parsing the instruction may pop
  // PushArguments off the stack.
  Environment* env = nullptr;
  if (auto const env_sexp = CheckList(list->ExtraLookupValue("env"))) {
    env = ParseEnvironment(env_sexp);
    if (env == nullptr) return nullptr;
  }

  Instruction* inst = nullptr;

#define HANDLE_CASE(name)                                                      \
  case kHandled##name:                                                         \
    inst = Deserialize##name(list, common_info);                               \
    break;
  switch (HandledInstructionForTag(tag)) {
    FOR_EACH_HANDLED_INSTRUCTION_IN_DESERIALIZER(HANDLE_CASE)
    case kHandledInvalid:
      StoreError(tag, "unhandled instruction");
      return nullptr;
  }
#undef HANDLE_CASE

  if (inst == nullptr) return nullptr;
  if (env != nullptr) env->DeepCopyTo(zone(), inst);
  return inst;
}

FunctionEntryInstr* FlowGraphDeserializer::DeserializeFunctionEntry(
    SExpList* sexp,
    const EntryInfo& info) {
  ASSERT(flow_graph_ != nullptr);
  auto const graph = flow_graph_->graph_entry();
  auto const block = new (zone())
      FunctionEntryInstr(graph, info.block_id, info.try_index, info.deopt_id);
  current_block_ = block;
  if (!ParseInitialDefinitions(sexp)) return nullptr;
  return block;
}

GraphEntryInstr* FlowGraphDeserializer::DeserializeGraphEntry(
    SExpList* sexp,
    const EntryInfo& info) {
  auto const name_sexp = CheckSymbol(Retrieve(sexp, 1));
  // TODO(sstrickl): If the FlowGraphDeserializer was constructed with a
  // non-null ParsedFunction, we should check that the name matches here.
  // If not, then we should create an appropriate ParsedFunction here.
  if (name_sexp == nullptr) return nullptr;

  intptr_t osr_id = Compiler::kNoOSRDeoptId;
  if (auto const osr_id_sexp = CheckInteger(sexp->ExtraLookupValue("osr_id"))) {
    osr_id = osr_id_sexp->value();
  }

  ASSERT(parsed_function_ != nullptr);
  return new (zone()) GraphEntryInstr(*parsed_function_, osr_id, info.deopt_id);
}

JoinEntryInstr* FlowGraphDeserializer::DeserializeJoinEntry(
    SExpList* sexp,
    const EntryInfo& info) {
  return new (zone())
      JoinEntryInstr(info.block_id, info.try_index, info.deopt_id);
}

TargetEntryInstr* FlowGraphDeserializer::DeserializeTargetEntry(
    SExpList* sexp,
    const EntryInfo& info) {
  return new (zone())
      TargetEntryInstr(info.block_id, info.try_index, info.deopt_id);
}

AllocateObjectInstr* FlowGraphDeserializer::DeserializeAllocateObject(
    SExpList* sexp,
    const InstrInfo& info) {
  auto& cls = Class::ZoneHandle(zone());
  auto const cls_sexp = CheckTaggedList(Retrieve(sexp, 1), "Class");
  if (!ParseDartValue(cls_sexp, &cls)) return nullptr;

  intptr_t args_len = 0;
  if (auto const len_sexp = CheckInteger(sexp->ExtraLookupValue("args_len"))) {
    args_len = len_sexp->value();
  }
  auto const arguments = FetchPushedArguments(sexp, args_len);
  if (arguments == nullptr) return nullptr;

  auto const inst =
      new (zone()) AllocateObjectInstr(info.token_pos, cls, arguments);

  if (auto const closure_sexp = CheckTaggedList(
          sexp->ExtraLookupValue("closure_function"), "Function")) {
    auto& closure_function = Function::Handle(zone());
    if (!ParseDartValue(closure_sexp, &closure_function)) return nullptr;
    inst->set_closure_function(closure_function);
  }

  return inst;
}

BranchInstr* FlowGraphDeserializer::DeserializeBranch(SExpList* sexp,
                                                      const InstrInfo& info) {
  auto const comp_sexp = CheckTaggedList(Retrieve(sexp, 1));
  auto const comp_inst = ParseInstruction(comp_sexp);
  if (comp_inst == nullptr) return nullptr;
  if (!comp_inst->IsComparison()) {
    StoreError(sexp->At(1), "expected comparison instruction");
    return nullptr;
  }
  auto const comparison = comp_inst->AsComparison();

  auto const true_block = FetchBlock(CheckSymbol(Retrieve(sexp, 2)));
  if (true_block == nullptr) return nullptr;
  if (!true_block->IsTargetEntry()) {
    StoreError(sexp->At(2), "true successor is not a target block");
    return nullptr;
  }

  auto const false_block = FetchBlock(CheckSymbol(Retrieve(sexp, 3)));
  if (false_block == nullptr) return nullptr;
  if (!false_block->IsTargetEntry()) {
    StoreError(sexp->At(3), "false successor is not a target block");
    return nullptr;
  }

  auto const branch = new (zone()) BranchInstr(comparison, info.deopt_id);
  *branch->true_successor_address() = true_block->AsTargetEntry();
  *branch->false_successor_address() = false_block->AsTargetEntry();
  return branch;
}

CheckNullInstr* FlowGraphDeserializer::DeserializeCheckNull(
    SExpList* sexp,
    const InstrInfo& info) {
  auto const val = ParseValue(Retrieve(sexp, 1));
  if (val == nullptr) return nullptr;

  auto& func_name = String::ZoneHandle(zone());
  if (auto const name_sexp =
          CheckString(sexp->ExtraLookupValue("function_name"))) {
    func_name = String::New(name_sexp->value(), Heap::kOld);
  }

  return new (zone())
      CheckNullInstr(val, func_name, info.deopt_id, info.token_pos);
}

CheckStackOverflowInstr* FlowGraphDeserializer::DeserializeCheckStackOverflow(
    SExpList* sexp,
    const InstrInfo& info) {
  intptr_t stack_depth = 0;
  if (auto const stack_sexp =
          CheckInteger(sexp->ExtraLookupValue("stack_depth"))) {
    stack_depth = stack_sexp->value();
  }

  intptr_t loop_depth = 0;
  if (auto const loop_sexp =
          CheckInteger(sexp->ExtraLookupValue("loop_depth"))) {
    loop_depth = loop_sexp->value();
  }

  auto kind = CheckStackOverflowInstr::kOsrAndPreemption;
  if (auto const kind_sexp = CheckSymbol(sexp->ExtraLookupValue("kind"))) {
    ASSERT(strcmp(kind_sexp->value(), "OsrOnly") == 0);
    kind = CheckStackOverflowInstr::kOsrOnly;
  }

  return new (zone()) CheckStackOverflowInstr(info.token_pos, stack_depth,
                                              loop_depth, info.deopt_id, kind);
}

ConstantInstr* FlowGraphDeserializer::DeserializeConstant(
    SExpList* sexp,
    const InstrInfo& info) {
  Object& obj = Object::ZoneHandle(zone());
  if (!ParseDartValue(Retrieve(sexp, 1), &obj)) return nullptr;
  return new (zone()) ConstantInstr(obj, info.token_pos);
}

DebugStepCheckInstr* FlowGraphDeserializer::DeserializeDebugStepCheck(
    SExpList* sexp,
    const InstrInfo& info) {
  auto kind = RawPcDescriptors::kAnyKind;
  if (auto const kind_sexp = CheckSymbol(Retrieve(sexp, "stub_kind"))) {
    if (!RawPcDescriptors::KindFromCString(kind_sexp->value(), &kind)) {
      StoreError(kind_sexp, "not a valid RawPcDescriptors::Kind name");
      return nullptr;
    }
  }
  return new (zone()) DebugStepCheckInstr(info.token_pos, kind, info.deopt_id);
}

GotoInstr* FlowGraphDeserializer::DeserializeGoto(SExpList* sexp,
                                                  const InstrInfo& info) {
  auto const block = FetchBlock(CheckSymbol(Retrieve(sexp, 1)));
  if (block == nullptr) return nullptr;
  if (!block->IsJoinEntry()) {
    StoreError(sexp->At(1), "target of goto must be join entry");
    return nullptr;
  }
  return new (zone()) GotoInstr(block->AsJoinEntry(), info.deopt_id);
}

LoadFieldInstr* FlowGraphDeserializer::DeserializeLoadField(
    SExpList* sexp,
    const InstrInfo& info) {
  auto const instance = ParseValue(Retrieve(sexp, 1));
  if (instance == nullptr) return nullptr;

  const Slot* slot;
  if (!ParseSlot(CheckTaggedList(Retrieve(sexp, 2)), &slot)) return nullptr;

  return new (zone()) LoadFieldInstr(instance, *slot, info.token_pos);
}

ParameterInstr* FlowGraphDeserializer::DeserializeParameter(
    SExpList* sexp,
    const InstrInfo& info) {
  ASSERT(current_block_ != nullptr);
  if (auto const index_sexp = CheckInteger(Retrieve(sexp, 1))) {
    return new (zone()) ParameterInstr(index_sexp->value(), current_block_);
  }
  return nullptr;
}

PushArgumentInstr* FlowGraphDeserializer::DeserializePushArgument(
    SExpList* sexp,
    const InstrInfo& info) {
  auto const val = ParseValue(Retrieve(sexp, 1));
  if (val == nullptr) return nullptr;
  auto const push = new (zone()) PushArgumentInstr(val);
  auto const stack = pushed_stack_map_.LookupValue(current_block_->block_id());
  ASSERT(stack != nullptr);
  stack->Add(push);
  return push;
}

ReturnInstr* FlowGraphDeserializer::DeserializeReturn(SExpList* list,
                                                      const InstrInfo& info) {
  Value* val = ParseValue(Retrieve(list, 1));
  if (val == nullptr) return nullptr;
  return new (zone()) ReturnInstr(info.token_pos, val, info.deopt_id);
}

SpecialParameterInstr* FlowGraphDeserializer::DeserializeSpecialParameter(
    SExpList* sexp,
    const InstrInfo& info) {
  ASSERT(current_block_ != nullptr);
  auto const kind_sexp = CheckSymbol(Retrieve(sexp, 1));
  if (kind_sexp == nullptr) return nullptr;
  SpecialParameterInstr::SpecialParameterKind kind;
  if (!SpecialParameterInstr::KindFromCString(kind_sexp->value(), &kind)) {
    StoreError(kind_sexp, "unknown special parameter kind");
    return nullptr;
  }
  return new (zone())
      SpecialParameterInstr(kind, info.deopt_id, current_block_);
}

StaticCallInstr* FlowGraphDeserializer::DeserializeStaticCall(
    SExpList* sexp,
    const InstrInfo& info) {
  auto& function = Function::ZoneHandle(zone());
  auto const function_sexp = CheckTaggedList(Retrieve(sexp, 1), "Function");
  if (!ParseDartValue(function_sexp, &function)) return nullptr;

  intptr_t type_args_len = 0;
  if (auto const type_args_len_sexp =
          CheckInteger(sexp->ExtraLookupValue("type_args_len"))) {
    type_args_len = type_args_len_sexp->value();
  }

  Array& argument_names = Array::ZoneHandle(zone());
  if (auto const arg_names_sexp =
          CheckList(sexp->ExtraLookupValue("arg_names"))) {
    argument_names = Array::New(arg_names_sexp->Length(), Heap::kOld);
    for (intptr_t i = 0, n = arg_names_sexp->Length(); i < n; i++) {
      auto name_sexp = CheckString(Retrieve(arg_names_sexp, i));
      if (name_sexp == nullptr) return nullptr;
      tmp_string_ = String::New(name_sexp->value(), Heap::kOld);
      argument_names.SetAt(i, tmp_string_);
    }
  }

  intptr_t args_len = 0;
  if (auto const args_len_sexp =
          CheckInteger(sexp->ExtraLookupValue("args_len"))) {
    args_len = args_len_sexp->value();
  }

  // Type arguments are wrapped in a TypeArguments array, so no matter how
  // many there are, they are contained in a single pushed argument.
  auto const all_args_len = (type_args_len > 0 ? 1 : 0) + args_len;
  auto const arguments = FetchPushedArguments(sexp, all_args_len);
  if (arguments == nullptr) return nullptr;

  intptr_t call_count = 0;
  if (auto const call_count_sexp =
          CheckInteger(sexp->ExtraLookupValue("call_count"))) {
    call_count = call_count_sexp->value();
  }

  auto rebind_rule = ICData::kInstance;
  if (auto const rebind_sexp =
          CheckSymbol(sexp->ExtraLookupValue("rebind_rule"))) {
    if (!ICData::RebindRuleFromCString(rebind_sexp->value(), &rebind_rule)) {
      StoreError(rebind_sexp, "unknown rebind rule value");
      return nullptr;
    }
  }

  return new (zone())
      StaticCallInstr(info.token_pos, function, type_args_len, argument_names,
                      arguments, info.deopt_id, call_count, rebind_rule);
}

StoreInstanceFieldInstr* FlowGraphDeserializer::DeserializeStoreInstanceField(
    SExpList* sexp,
    const InstrInfo& info) {
  auto const instance = ParseValue(Retrieve(sexp, 1));
  if (instance == nullptr) return nullptr;

  const Slot* slot = nullptr;
  if (!ParseSlot(CheckTaggedList(Retrieve(sexp, 2), "Slot"), &slot)) {
    return nullptr;
  }

  auto const value = ParseValue(Retrieve(sexp, 3));
  if (value == nullptr) return nullptr;

  auto barrier_type = kNoStoreBarrier;
  if (auto const bar_sexp = CheckBool(sexp->ExtraLookupValue("emit_barrier"))) {
    if (bar_sexp->value()) barrier_type = kEmitStoreBarrier;
  }

  auto kind = StoreInstanceFieldInstr::Kind::kOther;
  if (auto const init_sexp = CheckBool(sexp->ExtraLookupValue("is_init"))) {
    if (init_sexp->value()) kind = StoreInstanceFieldInstr::Kind::kInitializing;
  }

  return new (zone()) StoreInstanceFieldInstr(
      *slot, instance, value, barrier_type, info.token_pos, kind);
}

StrictCompareInstr* FlowGraphDeserializer::DeserializeStrictCompare(
    SExpList* sexp,
    const InstrInfo& info) {
  auto const token_sexp = CheckSymbol(Retrieve(sexp, 1));
  if (token_sexp == nullptr) return nullptr;
  Token::Kind kind;
  if (!Token::FromStr(token_sexp->value(), &kind)) return nullptr;

  auto const left = ParseValue(Retrieve(sexp, 2));
  if (left == nullptr) return nullptr;

  auto const right = ParseValue(Retrieve(sexp, 3));
  if (right == nullptr) return nullptr;

  bool needs_check = false;
  if (auto const check_sexp = CheckBool(Retrieve(sexp, "needs_check"))) {
    needs_check = check_sexp->value();
  }

  return new (zone()) StrictCompareInstr(info.token_pos, kind, left, right,
                                         needs_check, info.deopt_id);
}

Value* FlowGraphDeserializer::ParseValue(SExpression* sexp,
                                         bool allow_pending) {
  auto name = sexp->AsSymbol();
  CompileType* type = nullptr;
  if (name == nullptr) {
    auto const list = CheckTaggedList(sexp, "value");
    name = CheckSymbol(Retrieve(list, 1));
    if (name == nullptr) return nullptr;
    if (auto const type_sexp =
            CheckTaggedList(list->ExtraLookupValue("type"), "CompileType")) {
      type = ParseCompileType(type_sexp);
      if (type == nullptr) return nullptr;
    }
  }
  intptr_t index;
  if (!ParseUse(name, &index)) return nullptr;
  auto const def = definition_map_.LookupValue(index);
  Value* val;
  if (def == nullptr) {
    if (!allow_pending) {
      StoreError(sexp, "found use prior to definition");
      return nullptr;
    }
    val = AddNewPendingValue(index);
  } else {
    val = new (zone()) Value(def);
  }
  if (type != nullptr) val->SetReachingType(type);
  return val;
}

CompileType* FlowGraphDeserializer::ParseCompileType(SExpList* sexp) {
  // TODO(sstrickl): Currently we only print out nullable if it's false
  // (or during verbose printing). Switch this when NNBD is the standard.
  bool nullable = CompileType::kNullable;
  if (auto const nullable_sexp =
          CheckBool(sexp->ExtraLookupValue("nullable"))) {
    nullable = nullable_sexp->value() ? CompileType::kNullable
                                      : CompileType::kNonNullable;
  }

  // A cid as the second element means that the type is based off a concrete
  // class.
  intptr_t cid = kDynamicCid;
  if (sexp->Length() > 1) {
    if (auto const cid_sexp = CheckInteger(sexp->At(1))) {
      // TODO(sstrickl): Check that the cid is a valid cid.
      cid = cid_sexp->value();
    } else {
      return nullptr;
    }
  }

  AbstractType* type = nullptr;
  if (auto const type_sexp = CheckTaggedList(sexp->ExtraLookupValue("type"))) {
    auto& type_handle = AbstractType::ZoneHandle(zone());
    if (!ParseDartValue(type_sexp, &type_handle)) return nullptr;
    type = &type_handle;
  }
  return new (zone()) CompileType(nullable, cid, type);
}

Environment* FlowGraphDeserializer::ParseEnvironment(SExpList* list) {
  if (list == nullptr) return nullptr;
  intptr_t fixed_param_count = 0;
  if (auto const fpc_sexp =
          CheckInteger(list->ExtraLookupValue("fixed_param_count"))) {
    fixed_param_count = fpc_sexp->value();
  }
  Environment* outer_env = nullptr;
  if (auto const outer_sexp = CheckList(list->ExtraLookupValue("outer"))) {
    outer_env = ParseEnvironment(outer_sexp);
    if (outer_env == nullptr) return nullptr;
    if (auto const deopt_sexp =
            CheckInteger(outer_sexp->ExtraLookupValue("deopt_id"))) {
      outer_env->deopt_id_ = deopt_sexp->value();
    }
  }

  auto const env = new (zone()) Environment(list->Length(), fixed_param_count,
                                            *parsed_function_, outer_env);

  auto const stack = pushed_stack_map_.LookupValue(current_block_->block_id());
  ASSERT(stack != nullptr);
  for (intptr_t i = 0; i < list->Length(); i++) {
    auto const elem_sexp = Retrieve(list, i);
    if (elem_sexp == nullptr) return nullptr;
    auto val = ParseValue(elem_sexp, /*allow_pending=*/false);
    if (val == nullptr) {
      intptr_t index;
      if (!ParseSymbolAsPrefixedInt(CheckSymbol(elem_sexp), 'a', &index)) {
        StoreError(elem_sexp, "expected value or reference to pushed argument");
        return nullptr;
      }
      if (index >= stack->length()) {
        StoreError(elem_sexp, "out of range index for pushed argument");
        return nullptr;
      }
      val = new (zone()) Value(stack->At(index));
    }
    env->PushValue(val);
  }

  return env;
}

bool FlowGraphDeserializer::ParseDartValue(SExpression* sexp, Object* out) {
  ASSERT(out != nullptr);
  if (sexp == nullptr) return false;
  *out = Object::null();

  if (auto const sym = sexp->AsSymbol()) {
    // We'll use the null value in *out as a marker later, so go ahead and exit
    // early if we parse one.
    if (strcmp(sym->value(), "null") == 0) return true;

    // The only other symbols that should appear in Dart value position are
    // names of constant definitions.
    auto const val = ParseValue(sym, /*allow_pending=*/false);
    if (val == nullptr) return false;
    if (!val->BindsToConstant()) {
      StoreError(sym, "not a reference to a constant definition");
      return false;
    }
    *out = val->BoundConstant().raw();
    // Values used in constant definitions have already been canonicalized,
    // so just exit.
    return true;
  }

  // Other instance values may need to be canonicalized, so do that before
  // returning.
  if (auto const list = CheckTaggedList(sexp)) {
    auto const tag = list->At(0)->AsSymbol();
    if (strcmp(tag->value(), "Class") == 0) {
      auto const cid_sexp = CheckInteger(Retrieve(list, 1));
      if (cid_sexp == nullptr) return false;
      ClassTable* table = thread()->isolate()->class_table();
      if (!table->HasValidClassAt(cid_sexp->value())) {
        StoreError(cid_sexp, "no valid class found for cid");
        return false;
      }
      *out = table->At(cid_sexp->value());
    } else if (strcmp(tag->value(), "Type") == 0) {
      if (const auto cls_sexp = CheckTaggedList(Retrieve(list, 1), "Class")) {
        auto& cls = Class::ZoneHandle(zone());
        if (!ParseDartValue(cls_sexp, &cls)) return false;
        auto& type_args = TypeArguments::ZoneHandle(zone());
        if (const auto ta_sexp = CheckTaggedList(
                list->ExtraLookupValue("type_args"), "TypeArguments")) {
          if (!ParseDartValue(ta_sexp, &type_args)) return false;
        }
        *out = Type::New(cls, type_args, TokenPosition::kNoSource, Heap::kOld);
        // Need to set this for canonicalization. We ensure in the serializer
        // that only finalized types are successfully serialized.
        Type::Cast(*out).SetIsFinalized();
      }
      // TODO(sstrickl): Handle types not derived from classes.
    } else if (strcmp(tag->value(), "TypeArguments") == 0) {
      *out = TypeArguments::New(list->Length() - 1, Heap::kOld);
      auto& type_args = TypeArguments::Cast(*out);
      for (intptr_t i = 1, n = list->Length(); i < n; i++) {
        if (!ParseDartValue(Retrieve(list, i), &value_type_)) return false;
        type_args.SetTypeAt(i - 1, value_type_);
      }
    } else if (strcmp(tag->value(), "Field") == 0) {
      auto const name_sexp = CheckSymbol(Retrieve(list, 1));
      if (!ParseCanonicalName(name_sexp, out)) return false;
    } else if (strcmp(tag->value(), "Function") == 0) {
      auto const name_sexp = CheckSymbol(Retrieve(list, 1));
      if (!ParseCanonicalName(name_sexp, out)) return false;
      // Check the kind expected by the S-expression if one was specified.
      if (auto const kind_sexp = CheckSymbol(list->ExtraLookupValue("kind"))) {
        RawFunction::Kind kind;
        if (!RawFunction::KindFromCString(kind_sexp->value(), &kind)) {
          StoreError(kind_sexp, "unexpected function kind");
          return false;
        }
        auto& function = Function::Cast(*out);
        if (function.kind() != kind) {
          auto const kind_str = RawFunction::KindToCString(function.kind());
          StoreError(list, "retrieved function has kind %s", kind_str);
          return false;
        }
      }
    } else if (strcmp(tag->value(), "TypeParameter") == 0) {
      ASSERT(parsed_function_ != nullptr);
      auto const name_sexp = CheckSymbol(Retrieve(list, 1));
      if (name_sexp == nullptr) return false;
      const auto& func = parsed_function_->function();
      tmp_string_ = String::New(name_sexp->value());
      *out = func.LookupTypeParameter(tmp_string_, nullptr);
      if (out->IsNull()) {
        // Check the owning class for the function as well.
        value_class_ = func.Owner();
        *out = value_class_.LookupTypeParameter(tmp_string_);
      }
      // We'll want a more specific error message than the generic unhandled
      // Dart value one if this failed.
      if (out->IsNull()) {
        StoreError(name_sexp, "no type parameter found for name");
        return false;
      }
    } else if (strcmp(tag->value(), "ImmutableList") == 0) {
      // Since arrays can contain arrays, we must allocate a new handle here.
      auto& arr =
          Array::Handle(zone(), Array::New(list->Length() - 1, Heap::kOld));
      for (intptr_t i = 1; i < list->Length(); i++) {
        if (!ParseDartValue(Retrieve(list, i), &value_object_)) return false;
        arr.SetAt(i - 1, value_object_);
      }
      if (auto type_args_sexp = CheckTaggedList(
              list->ExtraLookupValue("type_args"), "TypeArguments")) {
        if (!ParseDartValue(type_args_sexp, &value_type_args_)) return false;
        arr.SetTypeArguments(value_type_args_);
      }
      arr.MakeImmutable();
      *out = arr.raw();
    } else if (strcmp(tag->value(), "Instance") == 0) {
      if (!ParseInstance(list, reinterpret_cast<Instance*>(out))) return false;
    } else if (strcmp(tag->value(), "Closure") == 0) {
      auto& function = Function::ZoneHandle(zone());
      if (!ParseDartValue(Retrieve(list, 1), &function)) return false;

      auto& context = Context::ZoneHandle(zone());
      if (list->ExtraLookupValue("context") != nullptr) {
        StoreError(list, "closures with contexts currently unhandled");
        return false;
      }

      auto& inst_type_args = TypeArguments::ZoneHandle(zone());
      if (auto const type_args_sexp = CheckTaggedList(
              Retrieve(list, "inst_type_args"), "TypeArguments")) {
        if (!ParseDartValue(type_args_sexp, &inst_type_args)) return false;
      }

      auto& func_type_args = TypeArguments::ZoneHandle(zone());
      if (auto const type_args_sexp = CheckTaggedList(
              Retrieve(list, "func_type_args"), "TypeArguments")) {
        if (!ParseDartValue(type_args_sexp, &func_type_args)) return false;
      }

      auto& delayed_type_args = TypeArguments::ZoneHandle(zone());
      if (auto const type_args_sexp = CheckTaggedList(
              Retrieve(list, "delayed_type_args"), "TypeArguments")) {
        if (!ParseDartValue(type_args_sexp, &delayed_type_args)) return false;
      }

      *out = Closure::New(inst_type_args, func_type_args, delayed_type_args,
                          function, context, Heap::kOld);
    }
  } else if (auto const b = sexp->AsBool()) {
    *out = Bool::Get(b->value()).raw();
  } else if (auto const str = sexp->AsString()) {
    *out = String::New(str->value(), Heap::kOld);
  } else if (auto const i = sexp->AsInteger()) {
    *out = Integer::New(i->value(), Heap::kOld);
  } else if (auto const d = sexp->AsDouble()) {
    *out = Double::New(d->value(), Heap::kOld);
  }

  // If we're here and still haven't gotten a non-null value, then something
  // went wrong. (Likely an unrecognized value.)
  if (out->IsNull()) {
    StoreError(sexp, "unhandled Dart value");
    return false;
  }

  if (out->IsInstance()) {
    const char* error_str = nullptr;
    // CheckAndCanonicalize uses the current zone for the passed in thread,
    // not an explicitly provided zone. This means we cannot be run in a context
    // where [thread()->zone()] does not match [zone()] (e.g., due to StackZone)
    // until this is addressed.
    *out = Instance::Cast(*out).CheckAndCanonicalize(thread(), &error_str);
    if (out->IsNull()) {
      if (error_str != nullptr) {
        StoreError(sexp, "error during canonicalization: %s", error_str);
      } else {
        StoreError(sexp, "unexpected error during canonicalization");
      }
      return false;
    }
  }
  return true;
}

bool FlowGraphDeserializer::ParseInstance(SExpList* list, Instance* out) {
  auto const cid_sexp = CheckInteger(Retrieve(list, 1));
  if (cid_sexp == nullptr) return false;

  auto const table = thread()->isolate()->class_table();
  if (!table->HasValidClassAt(cid_sexp->value())) {
    StoreError(cid_sexp, "cid is not valid");
    return false;
  }

  instance_class_ = table->At(cid_sexp->value());
  *out = Instance::New(instance_class_, Heap::kOld);

  if (list->Length() > 2) {
    auto const fields_sexp = CheckTaggedList(Retrieve(list, 2), "Fields");
    if (fields_sexp == nullptr) return false;
    auto it = fields_sexp->ExtraIterator();
    while (auto kv = it.Next()) {
      tmp_string_ = String::New(kv->key);
      instance_field_ = instance_class_.LookupFieldAllowPrivate(
          tmp_string_, /*instance_only=*/true);
      if (instance_field_.IsNull()) {
        StoreError(list, "cannot find field %s", kv->key);
        return false;
      }

      if (auto const inst = CheckTaggedList(kv->value, "Instance")) {
        // Unsure if this will be necessary, so for now not doing fresh
        // Instance/Class handle allocations unless it is.
        StoreError(inst, "nested instances not handled yet");
        return false;
      }
      if (!ParseDartValue(kv->value, &instance_object_)) return false;
      out->SetField(instance_field_, instance_object_);
    }
  }
  return true;
}

bool FlowGraphDeserializer::ParseCanonicalName(SExpSymbol* sym, Object* obj) {
  if (sym == nullptr) return false;
  auto const name = sym->value();
  // TODO(sstrickl): No library URL, handle this better.
  if (*name == ':') {
    StoreError(sym, "expected non-empty library");
    return false;
  }
  const char* lib_end = nullptr;
  if (auto const first = strchr(name, ':')) {
    lib_end = strchr(first + 1, ':');
    if (lib_end == nullptr) lib_end = strchr(first + 1, '\0');
  } else {
    StoreError(sym, "malformed library");
    return false;
  }
  tmp_string_ =
      String::FromUTF8(reinterpret_cast<const uint8_t*>(name), lib_end - name);
  name_library_ = Library::LookupLibrary(thread(), tmp_string_);
  if (*lib_end == '\0') {
    *obj = name_library_.raw();
    return true;
  }
  const char* const class_start = lib_end + 1;
  if (*class_start == '\0') {
    StoreError(sym, "no class found after colon");
    return false;
  }
  // If classes are followed by another part, it's either a function
  // (separated by ':') or a field (separated by '.').
  const char* class_end = strchr(class_start, ':');
  if (class_end == nullptr) class_end = strchr(class_start, '.');
  if (class_end == nullptr) class_end = strchr(class_start, '\0');
  const bool empty_name = class_end == class_start;
  name_class_ = Class::null();
  if (empty_name) {
    name_class_ = name_library_.toplevel_class();
  } else {
    tmp_string_ = String::FromUTF8(
        reinterpret_cast<const uint8_t*>(class_start), class_end - class_start);
    name_class_ = name_library_.LookupClassAllowPrivate(tmp_string_);
  }
  if (name_class_.IsNull()) {
    StoreError(sym, "failure looking up class %s in library %s",
               empty_name ? "at top level" : tmp_string_.ToCString(),
               name_library_.ToCString());
    return false;
  }
  if (*class_end == '\0') {
    *obj = name_class_.raw();
    return true;
  }
  if (*class_end == '.') {
    if (class_end[1] == '\0') {
      StoreError(sym, "no field name found after period");
      return false;
    }
    const char* const field_start = class_end + 1;
    const char* field_end = strchr(field_start, '\0');
    tmp_string_ = String::FromUTF8(
        reinterpret_cast<const uint8_t*>(field_start), field_end - field_start);
    name_field_ = name_class_.LookupFieldAllowPrivate(tmp_string_);
    if (name_field_.IsNull()) {
      StoreError(sym, "failure looking up field %s in class %s",
                 tmp_string_.ToCString(),
                 empty_name ? "at top level" : name_class_.ToCString());
      return false;
    }
    *obj = name_field_.raw();
    return true;
  }
  if (class_end[1] == '\0') {
    StoreError(sym, "no function name found after final colon");
    return false;
  }
  const char* func_start = class_end + 1;
  name_function_ = Function::null();
  while (true) {
    const char* func_end = strchr(func_start, ':');
    intptr_t name_len = func_end - func_start;
    bool is_forwarder = false;
    if (func_end != nullptr && name_len == 3) {
      // Special case for getters/setters, where they are prefixed with "get:"
      // or "set:", as those colons should not be used as separators.
      if (strncmp(func_start, "get", 3) == 0 ||
          strncmp(func_start, "set", 3) == 0) {
        func_end = strchr(func_end + 1, ':');
      } else if (strncmp(func_start, "dyn", 3) == 0) {
        // Dynamic invocation forwarders start with "dyn:" and we'll need to
        // look up the base function and then retrieve the forwarder from it.
        is_forwarder = true;
        func_start = func_end + 1;
        func_end = strchr(func_end + 1, ':');
      }
    }
    if (func_end == nullptr) func_end = strchr(func_start, '\0');
    name_len = func_end - func_start;

    // Check for tearoff names before we overwrite the contents of tmp_string_.
    if (!name_function_.IsNull()) {
      ASSERT(!tmp_string_.IsNull());
      auto const parent_name = tmp_string_.ToCString();
      // ImplicitClosureFunctions (tearoffs) have the same name as the Function
      // to which they are attached. We won't handle any further nesting.
      if (name_function_.HasImplicitClosureFunction() && *func_end == '\0' &&
          strncmp(parent_name, func_start, name_len) == 0) {
        *obj = name_function_.ImplicitClosureFunction();
        return true;
      }
      StoreError(sym, "no handling for local functions");
      return false;
    }

    tmp_string_ = String::FromUTF8(reinterpret_cast<const uint8_t*>(func_start),
                                   name_len);
    name_function_ = name_class_.LookupFunctionAllowPrivate(tmp_string_);
    if (name_function_.IsNull()) {
      StoreError(sym, "failure looking up function %s in class %s",
                 tmp_string_.ToCString(), name_class_.ToCString());
      return false;
    }
    if (is_forwarder) {
      // Go back four characters to start at the 'dyn:' we stripped earlier.
      tmp_string_ = String::FromUTF8(
          reinterpret_cast<const uint8_t*>(func_start - 4), name_len + 4);
      name_function_ =
          name_function_.GetDynamicInvocationForwarder(tmp_string_);
    }
    if (func_end[0] == '\0') break;
    if (func_end[1] == '\0') {
      StoreError(sym, "no function name found after final colon");
      return false;
    }
    func_start = func_end + 1;
  }
  *obj = name_function_.raw();
  return true;
}

// Following the lead of BaseFlowGraphBuilder::MayCloneField here.
const Field& FlowGraphDeserializer::MayCloneField(const Field& field) {
  if ((Compiler::IsBackgroundCompilation() ||
       FLAG_force_clone_compiler_objects) &&
      field.IsOriginal()) {
    return Field::ZoneHandle(zone(), field.CloneFromOriginal());
  }
  ASSERT(field.IsZoneHandle());
  return field;
}

bool FlowGraphDeserializer::ParseSlot(SExpList* list, const Slot** out) {
  ASSERT(out != nullptr);
  const auto offset_sexp = CheckInteger(Retrieve(list, 1));
  if (offset_sexp == nullptr) return false;
  const auto offset = offset_sexp->value();

  const auto kind_sexp = CheckSymbol(Retrieve(list, "kind"));
  if (kind_sexp == nullptr) return false;
  Slot::Kind kind;
  if (!Slot::KindFromCString(kind_sexp->value(), &kind)) {
    StoreError(kind_sexp, "unknown Slot kind");
    return false;
  }

  switch (kind) {
    case Slot::Kind::kDartField: {
      auto& field = Field::ZoneHandle(zone());
      const auto field_sexp = CheckTaggedList(Retrieve(list, "field"), "Field");
      if (!ParseDartValue(field_sexp, &field)) return false;
      *out = &Slot::Get(MayCloneField(field), parsed_function_);
      break;
    }
    case Slot::Kind::kTypeArguments:
      *out = &Slot::GetTypeArgumentsSlotAt(thread(), offset);
      break;
    case Slot::Kind::kCapturedVariable:
      StoreError(kind_sexp, "unhandled Slot kind");
      return false;
    default:
      *out = &Slot::GetNativeSlot(kind);
      break;
  }
  return true;
}

bool FlowGraphDeserializer::ParseBlockId(SExpSymbol* sym, intptr_t* out) {
  return ParseSymbolAsPrefixedInt(sym, 'B', out);
}

bool FlowGraphDeserializer::ParseSSATemp(SExpSymbol* sym, intptr_t* out) {
  return ParseSymbolAsPrefixedInt(sym, 'v', out);
}

bool FlowGraphDeserializer::ParseUse(SExpSymbol* sym, intptr_t* out) {
  // TODO(sstrickl): Handle non-SSA temp uses.
  return ParseSSATemp(sym, out);
}

bool FlowGraphDeserializer::ParseSymbolAsPrefixedInt(SExpSymbol* sym,
                                                     char prefix,
                                                     intptr_t* out) {
  ASSERT(out != nullptr);
  if (sym == nullptr) return false;
  auto const name = sym->value();
  if (*name != prefix) {
    StoreError(sym, "expected symbol starting with '%c'", prefix);
    return false;
  }
  int64_t i;
  if (!OS::StringToInt64(name + 1, &i)) {
    StoreError(sym, "expected number following symbol prefix '%c'", prefix);
    return false;
  }
  *out = i;
  return true;
}

Value* FlowGraphDeserializer::AddNewPendingValue(intptr_t index) {
  ASSERT(flow_graph_ != nullptr);
  auto const val = new (zone()) Value(flow_graph_->constant_null());
  AddPendingValue(index, val);
  return val;
}

void FlowGraphDeserializer::AddPendingValue(intptr_t index, Value* val) {
  ASSERT(!definition_map_.HasKey(index));
  auto value_list = values_map_.LookupValue(index);
  if (value_list == nullptr) {
    value_list = new (zone()) ZoneGrowableArray<Value*>(zone(), 2);
    values_map_.Insert(index, value_list);
  }
  value_list->Add(val);
}

void FlowGraphDeserializer::FixPendingValues(intptr_t index, Definition* def) {
  if (auto value_list = values_map_.LookupValue(index)) {
    for (intptr_t i = 0; i < value_list->length(); i++) {
      auto const val = value_list->At(i);
      val->BindTo(def);
    }
    values_map_.Remove(index);
  }
}

PushArgumentsArray* FlowGraphDeserializer::FetchPushedArguments(SExpList* list,
                                                                intptr_t len) {
  auto const stack = pushed_stack_map_.LookupValue(current_block_->block_id());
  ASSERT(stack != nullptr);
  auto const stack_len = stack->length();
  if (len > stack_len) {
    StoreError(list, "expected %" Pd " pushed arguments, only %" Pd " on stack",
               len, stack_len);
    return nullptr;
  }
  auto const arr = new (zone()) PushArgumentsArray(zone(), len);
  for (intptr_t i = 0; i < len; i++) {
    arr->Add(stack->At(stack_len - len + i));
  }
  stack->TruncateTo(stack_len - len);
  return arr;
}

BlockEntryInstr* FlowGraphDeserializer::FetchBlock(SExpSymbol* sym) {
  if (sym == nullptr) return nullptr;
  intptr_t block_id;
  if (!ParseBlockId(sym, &block_id)) return nullptr;
  auto const entry = block_map_.LookupValue(block_id);
  if (entry == nullptr) {
    StoreError(sym, "reference to undefined block");
    return nullptr;
  }
  return entry;
}

bool FlowGraphDeserializer::AreStacksConsistent(SExpList* list,
                                                PushStack* curr_stack,
                                                BlockEntryInstr* succ_block) {
  auto const curr_stack_len = curr_stack->length();
  for (intptr_t i = 0, n = succ_block->SuccessorCount(); i < n; i++) {
    auto const pred_block = succ_block->PredecessorAt(i);
    auto const pred_stack =
        pushed_stack_map_.LookupValue(pred_block->block_id());
    ASSERT(pred_stack != nullptr);
    if (pred_stack->length() != curr_stack_len) {
      StoreError(list->At(1),
                 "current pushed stack has %" Pd
                 " elements, "
                 "other pushed stack for B%" Pd " has %" Pd "",
                 curr_stack_len, pred_block->block_id(), pred_stack->length());
      return false;
    }
    for (intptr_t i = 0; i < curr_stack_len; i++) {
      // Leftover pushed arguments on the stack should come from dominating
      // nodes, so they should be the same PushedArgumentInstr no matter the
      // predecessor.
      if (pred_stack->At(i) != curr_stack->At(i)) {
        auto const pred_def = pred_stack->At(i)->value()->definition();
        auto const curr_def = curr_stack->At(i)->value()->definition();
        StoreError(list->At(1),
                   "current pushed stack has v%" Pd " at position %" Pd
                   ", "
                   "other pushed stack for B%" Pd " has v%" Pd "",
                   curr_def->ssa_temp_index(), i, pred_block->block_id(),
                   pred_def->ssa_temp_index());
        return false;
      }
    }
  }
  return true;
}

#define BASE_CHECK_DEF(name, type)                                             \
  SExp##name* FlowGraphDeserializer::Check##name(SExpression* sexp) {          \
    if (sexp == nullptr) return nullptr;                                       \
    if (!sexp->Is##name()) {                                                   \
      StoreError(sexp, "expected " #name);                                     \
      return nullptr;                                                          \
    }                                                                          \
    return sexp->As##name();                                                   \
  }

FOR_EACH_S_EXPRESSION(BASE_CHECK_DEF)

#undef BASE_CHECK_DEF

bool FlowGraphDeserializer::IsTag(SExpression* sexp, const char* label) {
  auto const sym = CheckSymbol(sexp);
  if (sym == nullptr) return false;
  if (label != nullptr && strcmp(label, sym->value()) != 0) {
    StoreError(sym, "expected symbol %s", label);
    return false;
  }
  return true;
}

SExpList* FlowGraphDeserializer::CheckTaggedList(SExpression* sexp,
                                                 const char* label) {
  auto const list = CheckList(sexp);
  const intptr_t tag_pos = 0;
  if (!IsTag(Retrieve(list, tag_pos), label)) return nullptr;
  return list;
}

void FlowGraphDeserializer::StoreError(SExpression* sexp,
                                       const char* format,
                                       ...) {
  va_list args;
  va_start(args, format);
  const char* const message = OS::VSCreate(zone(), format, args);
  va_end(args);
  error_sexp_ = sexp;
  error_message_ = message;
}

void FlowGraphDeserializer::ReportError() const {
  ASSERT(error_sexp_ != nullptr);
  ASSERT(error_message_ != nullptr);
  OS::PrintErr("Unable to deserialize flow_graph: %s\n", error_message_);
  OS::PrintErr("Error at S-expression %s\n", error_sexp_->ToCString(zone()));
  OS::Abort();
}

}  // namespace dart

#endif  // !defined(DART_PRECOMPILED_RUNTIME)
