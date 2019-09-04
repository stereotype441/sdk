// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#ifndef RUNTIME_VM_COMPILER_BACKEND_IL_DESERIALIZER_H_
#define RUNTIME_VM_COMPILER_BACKEND_IL_DESERIALIZER_H_

#include "platform/assert.h"

#include "vm/allocation.h"
#include "vm/compiler/backend/flow_graph.h"
#include "vm/compiler/backend/il.h"
#include "vm/compiler/backend/sexpression.h"
#include "vm/compiler/compiler_pass.h"
#include "vm/object.h"
#include "vm/parser.h"
#include "vm/thread.h"
#include "vm/zone.h"

namespace dart {

// Deserializes FlowGraphs from S-expressions.
class FlowGraphDeserializer : ValueObject {
 public:
  // Adds to the given array all the instructions in the flow graph that are
  // guaranteed not to be handled by the current implementation of the
  // FlowGraphDeserializer. This way, we can filter out graphs that are
  // guaranteed not to be deserializable before going through the round-trip
  // serialization process.
  //
  // Note that there may be other reasons that the deserializer may fail on
  // a given flow graph, so no new members of the array is necessary, but not
  // sufficient, for a successful round-trip pass.
  static void AllUnhandledInstructions(const FlowGraph* graph,
                                       GrowableArray<Instruction*>* out);

  // Takes the FlowGraph from [state] and runs it through the serializer
  // and deserializer. If the deserializer successfully deserializes the
  // graph, then the FlowGraph in [state] is replaced with the new one.
  static void RoundTripSerialization(CompilerPassState* state);

  FlowGraphDeserializer(Thread* thread,
                        Zone* zone,
                        SExpression* root,
                        const ParsedFunction* pf = nullptr)
      : thread_(ASSERT_NOTNULL(thread)),
        zone_(ASSERT_NOTNULL(zone)),
        root_sexp_(ASSERT_NOTNULL(root)),
        parsed_function_(pf),
        block_map_(zone_),
        definition_map_(zone_),
        values_map_(zone_),
        pushed_stack_(zone_, 2),
        instance_class_(Class::Handle(zone)),
        instance_field_(Field::Handle(zone)),
        instance_object_(Object::Handle(zone)),
        name_class_(Class::Handle(zone)),
        name_field_(Field::Handle(zone)),
        name_function_(Function::Handle(zone)),
        name_library_(Library::Handle(zone)),
        value_class_(Class::Handle(zone)),
        value_object_(Object::Handle(zone)),
        value_type_(AbstractType::Handle(zone)),
        value_type_args_(TypeArguments::Handle(zone)),
        tmp_string_(String::Handle(zone)) {
    // See canonicalization comment in ParseDartValue as to why this is
    // currently necessary.
    ASSERT(thread->zone() == zone);
  }

  // Walks [root_sexp_] and constructs a new FlowGraph.
  FlowGraph* ParseFlowGraph();

  const char* error_message() const { return error_message_; }
  SExpression* error_sexp() const { return error_sexp_; }

  // Prints the current error information to stderr and aborts.
  DART_NORETURN void ReportError() const;

 private:
#define FOR_EACH_HANDLED_BLOCK_TYPE_IN_DESERIALIZER(M)                         \
  M(FunctionEntry)                                                             \
  M(GraphEntry)                                                                \
  M(JoinEntry)                                                                 \
  M(TargetEntry)

#define FOR_EACH_HANDLED_INSTRUCTION_IN_DESERIALIZER(M)                        \
  M(Branch)                                                                    \
  M(CheckStackOverflow)                                                        \
  M(Constant)                                                                  \
  M(Goto)                                                                      \
  M(PushArgument)                                                              \
  M(Parameter)                                                                 \
  M(Return)                                                                    \
  M(SpecialParameter)                                                          \
  M(StaticCall)

  // Helper methods for AllUnhandledInstructions.
  static bool IsHandledInstruction(Instruction* inst);
  static bool IsHandledConstant(const Object& obj);

  // **GENERAL DESIGN NOTES FOR PARSING METHODS**
  //
  // For functions that take an SExpression or a subclass, they should return
  // an error signal (false, nullptr, etc.) without changing the error state if
  // passed in nullptr. This way, methods can be chained without intermediate
  // checking.
  //
  // Also, for parsing methods for expressions that are known to be of a certain
  // form, they will take the appropriate subclass of SExpression and assume
  // that the form was already pre-checked by the caller. For forms that are
  // tagged lists, this includes the fact that there is at least one element
  // and the first element is a symbol. If the form can only have one possible
  // tag, they also assume the tag has already been checked.

  // Helper functions that do length/key exists checking and also check that
  // the retrieved element is not nullptr. Notably, do not use these if the
  // retrieved element is optional, to avoid changing the error state
  // unnecessarily.
  SExpression* Retrieve(SExpList* list, intptr_t index);
  SExpression* Retrieve(SExpList* list, const char* key);

  bool ParseConstantPool(SExpList* pool);
  bool ParseEntries(SExpList* list);

  struct CommonEntryInfo {
    intptr_t block_id;
    intptr_t try_index;
    intptr_t deopt_id;
  };

#define HANDLER_DECL(name)                                                     \
  name##Instr* Handle##name(SExpList* list, const CommonEntryInfo& info);

  FOR_EACH_HANDLED_BLOCK_TYPE_IN_DESERIALIZER(HANDLER_DECL);

#undef HANDLER_DECL

  // Block parsing is split into two passes. This pass checks the
  // block ID and other extra information needed for certain block types.
  // In addition, it parses initial definitions found in the entry list.
  // The block is added to the [block_map_] as well as returned.
  BlockEntryInstr* ParseBlockHeader(SExpList* list, SExpSymbol* tag);

  // Expects [current_block_] to be set before calling.
  bool ParseInitialDefinitions(SExpList* list);

  // Expects [current_block_] to be set before calling.
  // Takes the tagged list to parse and the index where parsing should start.
  // Returns the index of the first non-Phi instruction or definition or -1 on
  // error.
  intptr_t ParsePhis(SExpList* list, intptr_t pos);

  // Parses the instructions in the body of a block. [current_block_] must be
  // set before calling.
  bool ParseBlockContents(SExpList* list);

  // Helper function used by ParseConstantPool, ParsePhis, and ParseDefinition.
  // This handles all the extra information stored in (def ...) expressions,
  // and also ensures the index of the definition is appropriately adjusted to
  // match those found in the serialized form.
  bool ParseDefinitionWithParsedBody(SExpList* list, Definition* def);

  Definition* ParseDefinition(SExpList* list);
  Instruction* ParseInstruction(SExpList* list);

  struct CommonInstrInfo {
    intptr_t deopt_id;
    TokenPosition token_pos;
  };

  enum HandledInstruction {
#define HANDLED_INST_DECL(name) kHandled##name,
    FOR_EACH_HANDLED_INSTRUCTION_IN_DESERIALIZER(HANDLED_INST_DECL)
#undef HANDLED_INST_DECL
    // clang-format off
    kHandledInvalid = -1,
    // clang-format on
  };

#define HANDLE_CASE(name)                                                      \
  if (strcmp(tag->value(), #name) == 0) return kHandled##name;
  HandledInstruction HandledInstructionForTag(SExpSymbol* tag) {
    ASSERT(tag != nullptr);
    FOR_EACH_HANDLED_INSTRUCTION_IN_DESERIALIZER(HANDLE_CASE)
    return kHandledInvalid;
  }
#undef HANDLE_CASE

#define HANDLER_DECL(name)                                                     \
  name##Instr* Handle##name(SExpList* list, const CommonInstrInfo& info);

  FOR_EACH_HANDLED_INSTRUCTION_IN_DESERIALIZER(HANDLER_DECL);

#undef HANDLER_DECL

  Value* ParseValue(SExpression* sexp);
  CompileType* ParseCompileType(SExpList* list);
  Environment* ParseEnvironment(SExpList* list);

  // Parsing functions for which there are no good distinguished error
  // values, so use out parameters and a boolean return instead.

  // Parses a Dart value and returns a canonicalized result.
  bool ParseDartValue(SExpression* sexp, Object* out);

  // Helper function for ParseDartValue for parsing instances.
  // Does not canonicalize (that is currently done in ParseDartValue), so
  // do not call this method directly.
  bool ParseInstance(SExpList* list, Instance* out);

  bool ParseCanonicalName(SExpSymbol* sym, Object* out);
  bool ParseBlockId(SExpSymbol* sym, intptr_t* out);
  bool ParseSSATemp(SExpSymbol* sym, intptr_t* out);
  bool ParseUse(SExpSymbol* sym, intptr_t* out);
  bool ParseSymbolAsPrefixedInt(SExpSymbol* sym, char prefix, intptr_t* out);

  // Helper function for creating a placeholder value when the definition
  // has not yet been seen.
  Value* AddNewPendingValue(intptr_t index);

  // Similar helper, but where we already have a created value.
  void AddPendingValue(intptr_t index, Value* val);

  // Helper function for rebinding pending values once the definition has
  // been located.
  void FixPendingValues(intptr_t index, Definition* def);

  // Creates a PushArgumentsArray of size [len] from [pushed_stack_] if there
  // are enough and pops the fetched arguments from the stack.
  //
  // The [sexp] argument should be the serialized form of the instruction that
  // needs the pushed arguments and is only used for error reporting.
  PushArgumentsArray* FetchPushedArguments(SExpList* sexp, intptr_t len);

  // Retrieves the block corresponding to the given block ID symbol from
  // [block_map_]. Assumes all blocks have had their header parsed.
  BlockEntryInstr* FetchBlock(SExpSymbol* sym);

  // Utility functions for checking the shape of an S-expression.
  // If these functions return nullptr for a non-null argument, they have the
  // side effect of setting the stored error message.
#define BASE_CHECK_DECL(name, type) SExp##name* Check##name(SExpression* sexp);
  FOR_EACH_S_EXPRESSION(BASE_CHECK_DECL)
#undef BASE_CHECK_DECL

  // Checks whether [sexp] is a symbol with the given label.
  bool IsTag(SExpression* sexp, const char* label);

  // A version of CheckList that also checks that the list has at least one
  // element and that the first element is a symbol. If [label] is non-null,
  // then the initial symbol element is checked against it.
  SExpList* CheckTaggedList(SExpression* sexp, const char* label = nullptr);

  // Stores appropriate error information using the SExpression as the location
  // and the rest of the arguments as an error message for the user.
  void StoreError(SExpression* s, const char* fmt, ...) PRINTF_ATTRIBUTE(3, 4);

  Thread* thread() const { return thread_; }
  Zone* zone() const { return zone_; }

  Thread* const thread_;
  Zone* const zone_;
  SExpression* const root_sexp_;
  const ParsedFunction* parsed_function_;

  FlowGraph* flow_graph_ = nullptr;
  BlockEntryInstr* current_block_ = nullptr;
  intptr_t max_block_id_ = -1;
  intptr_t max_ssa_index_ = -1;

  // Map from block IDs to blocks. Does not contain an entry for block 0
  // (the graph entry), since it is only used at known points and is already
  // available via [flow_graph_].
  IntMap<BlockEntryInstr*> block_map_;

  // Map from variable indexes to definitions.
  IntMap<Definition*> definition_map_;

  // Map from variable indices to lists of values. The list of values are
  // values that were parsed prior to the corresponding definition being found.
  IntMap<ZoneGrowableArray<Value*>*> values_map_;

  // Stack of currently pushed arguments, used by environment parsing and calls.
  GrowableArray<PushArgumentInstr*> pushed_stack_;

  // Temporary handles used by functions that are not re-entrant or where the
  // handle is not live after the re-entrant call. Comments show which handles
  // are expected to only be used within a single method.
  Class& instance_class_;           // ParseInstance
  Field& instance_field_;           // ParseInstance
  Object& instance_object_;         // ParseInstance
  Class& name_class_;               // ParseCanonicalName
  Field& name_field_;               // ParseCanonicalName
  Function& name_function_;         // ParseCanonicalName
  Library& name_library_;           // ParseCanonicalName
  Class& value_class_;              // ParseDartValue
  Object& value_object_;            // ParseDartValue
  AbstractType& value_type_;        // ParseDartValue
  TypeArguments& value_type_args_;  // ParseDartValue
  // Uses of string handles tend to be immediate, so we only need one.
  String& tmp_string_;

  // Stores a message appropriate to surfacing to the user when an error
  // occurs.
  const char* error_message_ = nullptr;
  // Stores the location of the deserialization error by containing the
  // S-expression which caused the failure.
  SExpression* error_sexp_ = nullptr;

  DISALLOW_COPY_AND_ASSIGN(FlowGraphDeserializer);
};

}  // namespace dart

#endif  // RUNTIME_VM_COMPILER_BACKEND_IL_DESERIALIZER_H_
