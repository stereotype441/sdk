#!/usr/bin/env lucicfg

# Copyright (c) 2019 The Dart project authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# Use ./main.star to regenerate the Luci configuration based on this file.
#
# Documentation for lucicfg is here:
# https://chromium.googlesource.com/infra/luci/luci-go/+/master/lucicfg/doc/

DART_GIT = "https://dart.googlesource.com/sdk"
DART_GERRIT = "https://dart-review.googlesource.com/sdk"

RELEASE_CHANNELS = ["dev", "stable"]
CHANNELS = RELEASE_CHANNELS + ["try"]
ANALYZER_CHANNELS = ["analyzer-stable"] + CHANNELS
BRANCHES = ["master", "dev", "stable"]

TEST_PY_PATHS = "pkg/(async_helper|expect|smith|status_file|test_runner)/.+"

STANDARD_PATHS = [
    "DEPS",  # DEPS catches most third_party changes.
    # build files
    "build/.+",
    "BUILD.gn",
    "sdk_args.gni",
    # core libraries
    "sdk(_nnbd)?/.+",
    # testing
    TEST_PY_PATHS,
    "tools/bots/test_matrix.json",
    # tests
    "tests/.+",
]

VM_PATHS = STANDARD_PATHS + [
    # VM sources
    "pkg/(front_end|kernel|vm|_fe_analyzer_shared)/.+",
    "runtime/.+",
]

DART2JS_PATHS = STANDARD_PATHS + [
    # compiler sources
    "pkg/(compiler|dart2js_tools|front_end|kernel|js_ast|_fe_analyzer_shared)/.+",
    "utils/compiler/.+",
    # testing
    "pkg/(js|modular_test|sourcemap_testing)/.+",
]

DDC_PATHS = STANDARD_PATHS + [
    # compiler sources
    "pkg/(analyzer|build_integration|dev_compiler|front_end|kernel|meta|_fe_analyzer_shared)/.+",
    "utils/dartdevc/.+",
    # testing
    "pkg/(js|modular_test|sourcemap_testing|testing)/.+",
]


def to_location_regexp(paths):
    return [".+/[+]/%s" % path for path in paths]


def mac():
    return {"os": "Mac"}


def windows():
    return {"os": "Windows"}


CI_ACCOUNT = "dart-luci-ci-builder@dart-ci.iam.gserviceaccount.com"
TRY_ACCOUNT = "dart-luci-try-builder@dart-ci.iam.gserviceaccount.com"
CI_TRIGGERERS = ["luci-scheduler@appspot.gserviceaccount.com", CI_ACCOUNT]
CI_SANDBOX_TRIGGERERS = CI_TRIGGERERS + [TRY_ACCOUNT]

lucicfg.config(
    config_dir=".",
    tracked_files=[
        "commit-queue.cfg",
        "cr-buildbucket.cfg",
        "luci-logdog.cfg",
        "luci-milo.cfg",
        "luci-notify.cfg",
        "luci-scheduler.cfg",
        "project.cfg",
    ],
)

luci.project(
    name="dart",
    buildbucket="cr-buildbucket.appspot.com",
    logdog="luci-logdog.appspot.com",
    milo="luci-milo.appspot.com",
    notify="luci-notify.appspot.com",
    scheduler="luci-scheduler.appspot.com",
    swarming="chromium-swarm.appspot.com",
    acls=[
        acl.entry(
            [
                acl.BUILDBUCKET_READER, acl.LOGDOG_READER,
                acl.PROJECT_CONFIGS_READER, acl.SCHEDULER_READER
            ],
            groups=["all"],
        ),
        acl.entry(acl.LOGDOG_WRITER, groups=["luci-logdog-chromium-writers"]),
        acl.entry([acl.SCHEDULER_OWNER, acl.BUILDBUCKET_TRIGGERER],
                  groups=["project-dart-admins"]),
        acl.entry(acl.CQ_COMMITTER, groups=["project-dart-committers"]),
        acl.entry(acl.CQ_DRY_RUNNER, groups=["project-dart-tryjob-access"]),
    ],
)

luci.milo(
    logo="https://storage.googleapis.com/chrome-infra-public/logo/dartlang.png",
)

luci.console_view(
    name="analyzer-stable",
    repo="https://dart.googlesource.com/sdk",
    title="SDK Analyzer Stable Branch Console",
    refs=["refs/heads/analyzer-stable"],
    header="console-header.textpb",
)

luci.console_view(
    name="be",
    repo="https://dart.googlesource.com/sdk",
    title="SDK Bleeding Edge Console",
    refs=["refs/heads/master"],
    header="console-header.textpb",
)

luci.console_view(
    name="alt",
    repo="https://dart.googlesource.com/sdk",
    title="SDK Bleeding Edge Console (alternative)",
    refs=["refs/heads/master"],
    header="console-header.textpb",
)

luci.console_view(
    name="dev",
    repo="https://dart.googlesource.com/sdk",
    title="SDK Dev Console",
    refs=["refs/heads/dev"],
    header="console-header.textpb",
)

luci.console_view(
    name="stable",
    repo="https://dart.googlesource.com/sdk",
    title="SDK Stable Console",
    refs=["refs/heads/stable"],
    header="console-header.textpb",
)

luci.console_view(
    name="flutter",
    repo=DART_GIT,
    title="Dart/Flutter Console",
    refs=["refs/heads/master"],
)

luci.console_view(
    name="flutter-hhh",
    repo="https://dart.googlesource.com/linear_sdk_flutter_engine",
    title="Dart/Flutter Linear History Console",
    refs=["refs/heads/master"],
)

luci.console_view(
    name="fyi",
    repo=DART_GIT,
    title="SDK FYI Console",
    refs=["refs/heads/master"],
)

luci.list_view(
    name="cq",
    title="SDK CQ Console",
)

luci.logdog(gs_bucket="chromium-luci-logdog")

luci.bucket(
    name="ci",
    acls=[
        acl.entry(acl.BUILDBUCKET_TRIGGERER, users=CI_TRIGGERERS),
    ],
)
luci.bucket(
    name="ci.sandbox",
    acls=[
        acl.entry(acl.BUILDBUCKET_TRIGGERER, users=CI_SANDBOX_TRIGGERERS),
    ],
)
luci.bucket(
    name="try",
    acls=[
        acl.entry(
            acl.BUILDBUCKET_TRIGGERER,
            groups=["project-dart-tryjob-access", "service-account-cq"]),
    ],
)

luci.gitiles_poller(
    name="dart-gitiles-trigger-flutter",
    bucket="ci",
    repo="https://dart.googlesource.com/linear_sdk_flutter_engine/",
    refs=["refs/heads/master"],
)


def dart_poller(name, bucket="ci", branches=BRANCHES, paths=None):
    for branch in branches:
        luci.gitiles_poller(
            name="%s-%s" % (name, branch),
            bucket=bucket,
            path_regexps=paths,
            repo=DART_GIT,
            refs=["refs/heads/%s" % branch],
        )


dart_poller("dart-gitiles-trigger", branches=BRANCHES + ["analyzer-stable"])
dart_poller("dart-vm-gitiles-trigger", branches=["master"], paths=VM_PATHS)

luci.gitiles_poller(
    name="dart-flutter-engine-trigger",
    bucket="ci",
    repo="https://dart.googlesource.com/external/github.com/flutter/engine",
    refs=["refs/heads/master"],
)

luci.gitiles_poller(
    name="dart-flutter-flutter-trigger",
    bucket="ci",
    repo="https://dart.googlesource.com/external/github.com/flutter/flutter",
    refs=["refs/heads/master"],
)

luci.notifier(
    name="infra",
    on_new_failure=True,
    notify_emails=[
        "athom@google.com", "sortie@google.com", "whesse@google.com"
    ])

luci.notifier(
    name="dart",
    on_new_failure=True,
    notify_emails=["athom@google.com"],
    notify_blamelist=True)

luci.notifier(
    name="dart-fuzz-testing",
    on_success=True,
    on_failure=True,
    notify_emails=["ajcbik@google.com", "athom@google.com"])

luci.notifier(
    name="frontend-team", on_failure=True, notify_emails=["jensj@google.com"])

luci.cq(
    submit_max_burst=2,
    submit_burst_delay=8 * time.minute,
)

luci.cq_group(
    name="sdk",
    watch=cq.refset(DART_GERRIT, refs=["refs/heads/.+"]),
    allow_submit_with_open_deps=True,
    tree_status_host="dart-status.appspot.com",
    retry_config=cq.RETRY_NONE,
    verifiers=None,
    cancel_stale_tryjobs=True,
)


def dart_recipe(name):
    return luci.recipe(
        name="dart/" + name,
        cipd_package=
        "infra/recipe_bundles/chromium.googlesource.com/chromium/tools/build",
    )


def dart_try_builder(name,
                     recipe="neo",
                     dimensions={},
                     execution_timeout=None,
                     experiment_percentage=None,
                     location_regexp=None,
                     properties={},
                     on_cq=False):
    dimensions = dict(dimensions)
    dimensions["pool"] = "luci.dart.try"
    dimensions.setdefault("os", "Linux")
    dimensions.setdefault("host_class", "default")
    dimensions.setdefault("cpu", "x86-64")
    properties.setdefault("clobber", "true")
    builder = name + "-try"

    luci.builder(
        name=builder,
        build_numbers=True,
        bucket="try",
        caches=[swarming.cache("browsers")],
        dimensions=dimensions,
        executable=dart_recipe(recipe),
        execution_timeout=execution_timeout,
        priority=30,
        properties=properties,
        service_account=TRY_ACCOUNT,
        swarming_tags=["vpython:native-python-wrapper"],
    )
    if on_cq:
        luci.cq_tryjob_verifier(
            builder=builder,
            cq_group='sdk',
            experiment_percentage=experiment_percentage,
            location_regexp=location_regexp)
        luci.list_view_entry(
            list_view="cq",
            builder=builder,
        )


postponed_alt_console_entries = []


def dart_builder(name,
                 bucket,
                 recipe="neo",
                 enabled=True,
                 category=None,
                 channels=[],
                 dimensions={},
                 cpu="x86-64",
                 execution_timeout=None,
                 fyi=False,
                 notifies="dart",
                 priority=50,
                 properties={},
                 schedule="triggered",
                 service_account=TRY_ACCOUNT,
                 triggered_by=None,
                 triggering_policy=None,
                 on_cq=False,
                 experiment_percentage=None,
                 location_regexp=None):
    dimensions.setdefault("os", "Linux")
    dimensions.setdefault("host_class", "default")
    dimensions.setdefault("pool", "luci.dart.try")
    dimensions["cpu"] = cpu
    properties.setdefault("clobber", "true")

    def builder(channel=None, triggered_by=None):
        if channel == "try":
            dart_try_builder(
                name,
                recipe=recipe,
                dimensions=dimensions,
                properties=properties,
                on_cq=on_cq,
                execution_timeout=execution_timeout,
                experiment_percentage=experiment_percentage,
                location_regexp=location_regexp)
        else:
            builder = name + "-" + channel if channel else name
            branch = channel if channel else "master"
            channel_properties = dict(properties)
            if channel in ['dev', 'stable']:
                channel_properties['no_approvals'] = True
            if enabled and schedule == "triggered":
                if not triggered_by:
                    triggered_by = ["dart-gitiles-trigger-%s"]
                triggered_by = [
                    trigger.replace("%s", branch) for trigger in triggered_by
                ]
                if channel in ['dev', 'stable']:
                    # Always run vm builders on dev and stable.
                    triggered_by = [
                        trigger.replace("dart-vm-", "dart-")
                        for trigger in triggered_by
                    ]
            luci.builder(
                name=builder,
                build_numbers=True,
                bucket=bucket,
                caches=[swarming.cache("browsers")],
                dimensions=dimensions,
                executable=dart_recipe(recipe),
                execution_timeout=execution_timeout,
                priority=priority,
                properties=channel_properties,
                notifies=[notifies]
                if notifies and not channel and enabled else None,
                schedule=schedule if enabled else None,
                service_account=service_account,
                swarming_tags=["vpython:native-python-wrapper"],
                triggered_by=triggered_by,
                triggering_policy=triggering_policy)
            if category:
                console_category, _, short_name = category.rpartition("|")
                toplevel_category, _, _ = console_category.partition("|")
                console = channel or "be" if not fyi else "fyi"
                luci.console_view_entry(
                    builder=builder,
                    short_name=short_name,
                    category=console_category,
                    console_view=console,
                )
                if console == "be":
                    if toplevel_category == "vm":
                        postponed_alt_console_entries.append({
                            "builder":
                            builder,
                            "short_name":
                            short_name,
                            "category":
                            console_category,
                        })
                    else:
                        luci.console_view_entry(
                            builder=builder,
                            short_name=short_name,
                            category=console_category,
                            console_view="alt",
                        )

    builder(triggered_by=triggered_by)
    for channel in channels:
        if enabled:
            builder(channel, triggered_by=triggered_by)


def dart_ci_builder(name, dimensions={}, **kwargs):
    dimensions.setdefault("pool", "luci.dart.ci")
    dart_builder(
        name,
        bucket="ci",
        dimensions=dimensions,
        service_account=CI_ACCOUNT,
        **kwargs)


def dart_ci_sandbox_builder(name, channels=CHANNELS, properties={}, **kwargs):
    if not properties.setdefault("new_workflow_enabled", True):
        properties.pop("new_workflow_enabled")

    dart_builder(
        name,
        bucket="ci.sandbox",
        channels=channels,
        properties=properties,
        service_account=TRY_ACCOUNT,
        **kwargs)


def dart_vm_extra_builder(name, on_cq=False, location_regexp=None, **kwargs):
    triggered_by = ["dart-vm-gitiles-trigger-%s"]
    if on_cq and not location_regexp:
        location_regexp = to_location_regexp(VM_PATHS)
    dart_ci_sandbox_builder(
        name,
        triggered_by=triggered_by,
        on_cq=on_cq,
        location_regexp=location_regexp,
        **kwargs)


# fasta
dart_ci_sandbox_builder(
    "front-end-linux-release-x64", category="fasta|l", on_cq=True)
dart_ci_sandbox_builder(
    "front-end-mac-release-x64", category="fasta|m", dimensions=mac())
dart_ci_sandbox_builder(
    "front-end-win-release-x64", category="fasta|w", dimensions=windows())
dart_ci_sandbox_builder(
    "flutter-frontend",
    category="fasta|fl",
    channels=["try"],
    properties={"new_workflow_enabled": False},
    notifies="frontend-team")

# flutter
dart_ci_sandbox_builder(
    "flutter-engine-linux",
    recipe="flutter_engine",
    category="flutter|3H",
    channels=["try"],
    execution_timeout=time.duration(5 * 60 * 60 * 1000),
    properties={"new_workflow_enabled": False},
    triggered_by=["dart-gitiles-trigger-flutter"],
)

# vm|ast
dart_vm_extra_builder("vm-kernel-ast-linux-debug-ia32", category="vm|ast|d32")
dart_vm_extra_builder("vm-kernel-ast-linux-release-ia32", category="vm|ast|r32")
dart_vm_extra_builder("vm-kernel-ast-linux-debug-x64", category="vm|ast|d")
dart_vm_extra_builder(
    "vm-kernel-ast-linux-release-simarm", category="vm|ast|psr")
dart_vm_extra_builder(
    "vm-kernel-ast-linux-release-simarm64", category="vm|ast|psr6")
dart_vm_extra_builder("vm-kernel-ast-linux-release-x64", category="vm|ast|r")
dart_vm_extra_builder(
    "vm-kernel-ast-win-debug-x64", category="vm|ast|wd", dimensions=windows())
dart_vm_extra_builder(
    "vm-kernel-ast-win-release-x64", category="vm|ast|wr", dimensions=windows())
dart_vm_extra_builder(
    "vm-kernel-precomp-ast-linux-debug-x64", category="vm|ast|pd")
dart_vm_extra_builder(
    "vm-kernel-precomp-ast-linux-release-simarm_x64", category="vm|ast|psr")
dart_vm_extra_builder(
    "vm-kernel-precomp-ast-linux-release-simarm64", category="vm|ast|psr6")
dart_vm_extra_builder(
    "vm-kernel-precomp-ast-linux-release-x64", category="vm|ast|pr")

# vm|app-kernel
dart_vm_extra_builder(
    "app-kernel-linux-debug-x64", category="vm|app-kernel|d64")
dart_vm_extra_builder(
    "app-kernel-linux-product-x64", category="vm|app-kernel|p64")
dart_vm_extra_builder(
    "app-kernel-linux-release-x64", category="vm|app-kernel|r64")

# vm|dartkb
dart_vm_extra_builder(
    "vm-dartkb-linux-release-simarm64", category="vm|dartkb|sr")
dart_vm_extra_builder("vm-dartkb-linux-release-x64", category="vm|dartkb|r")
dart_vm_extra_builder(
    "vm-dartkb-linux-release-x64-abi", category="vm|dartkb|abi")

#vm|kernel
dart_ci_sandbox_builder(
    "vm-canary-linux-debug", category="vm|kernel|c", on_cq=True)
dart_ci_sandbox_builder("vm-kernel-linux-debug-x64", category="vm|kernel|d")
dart_vm_extra_builder(
    "vm-kernel-linux-release-simarm", category="vm|kernel|a32")
dart_vm_extra_builder(
    "vm-kernel-linux-release-simarm64", category="vm|kernel|a64")
dart_vm_extra_builder("vm-kernel-linux-release-ia32", category="vm|kernel|r32")
dart_ci_sandbox_builder(
    "vm-kernel-linux-release-x64", category="vm|kernel|r", on_cq=True)
dart_vm_extra_builder(
    "vm-kernel-checked-linux-release-x64", category="vm|kernel|rc")
dart_vm_extra_builder("vm-kernel-linux-debug-ia32", category="vm|kernel|d32")
dart_ci_sandbox_builder(
    "vm-kernel-mac-debug-x64", category="vm|kernel|md", dimensions=mac())
dart_ci_sandbox_builder(
    "vm-kernel-mac-release-x64",
    category="vm|kernel|mr",
    dimensions=mac(),
    on_cq=True,
    experiment_percentage=5)
dart_vm_extra_builder(
    "vm-kernel-win-debug-ia32", category="vm|kernel|wd3", dimensions=windows())
dart_ci_sandbox_builder(
    "vm-kernel-win-debug-x64", category="vm|kernel|wd", dimensions=windows())
dart_vm_extra_builder(
    "vm-kernel-win-release-ia32",
    category="vm|kernel|wr3",
    dimensions=windows())
dart_ci_sandbox_builder(
    "vm-kernel-win-release-x64", category="vm|kernel|wr", dimensions=windows())
dart_vm_extra_builder(
    "cross-vm-linux-release-arm64",
    category="vm|kernel|cra",
    channels=RELEASE_CHANNELS)

# vm|kernel-precomp
dart_vm_extra_builder(
    "vm-kernel-precomp-linux-debug-x64", category="vm|kernel-precomp|d")
dart_vm_extra_builder(
    "vm-kernel-precomp-linux-product-x64", category="vm|kernel-precomp|p")
dart_vm_extra_builder(
    "vm-kernel-precomp-linux-release-simarm", category="vm|kernel-precomp|a32")
dart_vm_extra_builder(
    "vm-kernel-precomp-linux-release-simarm64",
    category="vm|kernel-precomp|a64")
dart_vm_extra_builder(
    "vm-kernel-precomp-linux-release-x64", category="vm|kernel-precomp|r")
dart_vm_extra_builder(
    "vm-kernel-precomp-bare-linux-release-x64", category="vm|kernel-precomp|b")
dart_vm_extra_builder(
    "vm-kernel-precomp-bare-linux-release-simarm",
    category="vm|kernel-precomp|b32")
dart_vm_extra_builder(
    "vm-kernel-precomp-bare-linux-release-simarm64",
    category="vm|kernel-precomp|b64")
dart_vm_extra_builder(
    "vm-kernel-precomp-obfuscate-linux-release-x64",
    category="vm|kernel-precomp|o")
dart_vm_extra_builder(
    "vm-kernel-precomp-linux-debug-simarm_x64",
    category="vm|kernel-precomp|adx",
    properties={"shard_timeout": 5400})  # 1.5h
dart_vm_extra_builder(
    "vm-kernel-precomp-mac-release-simarm_x64",
    category="vm|kernel-precomp|arx",
    dimensions=mac())
dart_vm_extra_builder(
    "vm-kernel-precomp-mac-release-simarm64",
    category="vm|kernel-precomp|ma",
    dimensions=mac())
dart_vm_extra_builder(
    "vm-kernel-precomp-win-release-x64",
    category="vm|kernel-precomp|wr",
    dimensions=windows())

# vm|kernel-precomp|android
dart_vm_extra_builder(
    "vm-kernel-precomp-android-release-arm_x64",
    category="vm|kernel-precomp|android|a32",
    properties={"shard_timeout": 5400})  # 1.5h
dart_vm_extra_builder(
    "vm-kernel-precomp-android-release-arm64",
    category="vm|kernel-precomp|android|a64",
    properties={"shard_timeout": 5400})  # 1.5h

# vm|misc
dart_vm_extra_builder(
    "vm-kernel-asan-linux-release-x64", category="vm|misc|a64")
dart_vm_extra_builder(
    "vm-kernel-optcounter-threshold-linux-release-ia32", category="vm|misc|o32")
dart_vm_extra_builder(
    "vm-kernel-optcounter-threshold-linux-release-x64", category="vm|misc|o64")

# vm|product
dart_ci_sandbox_builder(
    "vm-kernel-linux-product-x64", category="vm|product|l", on_cq=True)
dart_ci_sandbox_builder(
    "vm-kernel-mac-product-x64", category="vm|product|m", dimensions=mac())
dart_ci_sandbox_builder(
    "vm-kernel-win-product-x64", category="vm|product|w", dimensions=windows())

# vm|reload-kernel
dart_vm_extra_builder(
    "vm-kernel-reload-linux-debug-x64", category="vm|reload-kernel|d")
dart_vm_extra_builder(
    "vm-kernel-reload-linux-release-x64", category="vm|reload-kernel|r")
dart_vm_extra_builder(
    "vm-kernel-reload-rollback-linux-debug-x64",
    category="vm|reload-kernel|drb")
dart_vm_extra_builder(
    "vm-kernel-reload-rollback-linux-release-x64",
    category="vm|reload-kernel|rrb")

# vm|ffi
dart_vm_extra_builder("vm-ffi-android-debug-arm", category="vm|ffi|d32")
dart_vm_extra_builder("vm-ffi-android-release-arm", category="vm|ffi|r32")
dart_vm_extra_builder("vm-ffi-android-product-arm", category="vm|ffi|p32")
dart_vm_extra_builder("vm-ffi-android-debug-arm64", category="vm|ffi|d64")
dart_vm_extra_builder("vm-ffi-android-release-arm64", category="vm|ffi|r64")
dart_vm_extra_builder("vm-ffi-android-product-arm64", category="vm|ffi|p64")

# dart2js
dart_ci_sandbox_builder(
    "dart2js-strong-hostasserts-linux-ia32-d8",
    category="dart2js|d8|ha",
    location_regexp=to_location_regexp(DART2JS_PATHS),
    on_cq=True)
dart_ci_sandbox_builder("dart2js-rti-linux-x64-d8", category="dart2js|d8|rti")
dart_ci_sandbox_builder(
    "dart2js-minified-strong-linux-x64-d8",
    category="dart2js|d8|mi",
    location_regexp=to_location_regexp(DART2JS_PATHS),
    on_cq=True)
dart_ci_sandbox_builder(
    "dart2js-unit-linux-x64-release",
    category="dart2js|d8|u",
    location_regexp=to_location_regexp(DART2JS_PATHS),
    on_cq=True)
dart_ci_sandbox_builder(
    "dart2js-strong-linux-x64-chrome",
    category="dart2js|chrome|l",
    location_regexp=to_location_regexp(DART2JS_PATHS),
    on_cq=True)
dart_ci_sandbox_builder(
    "dart2js-csp-minified-linux-x64-chrome", category="dart2js|chrome|csp")
dart_ci_sandbox_builder(
    "dart2js-strong-mac-x64-chrome",
    category="dart2js|chrome|m",
    dimensions=mac())
dart_ci_sandbox_builder(
    "dart2js-strong-win-x64-chrome",
    category="dart2js|chrome|w",
    dimensions=windows())
dart_ci_sandbox_builder(
    "dart2js-strong-linux-x64-firefox", category="dart2js|firefox|l")
dart_ci_sandbox_builder(
    "dart2js-strong-win-x64-firefox",
    category="dart2js|firefox|w",
    dimensions=windows(),
    enabled=False)
dart_ci_sandbox_builder(
    "dart2js-strong-mac-x64-safari",
    category="dart2js|safari|m",
    dimensions=mac())
dart_ci_sandbox_builder(
    "dart2js-strong-win-x64-ie11",
    category="dart2js|ms|ie",
    dimensions=windows())

# analyzer
dart_ci_sandbox_builder(
    "flutter-analyze",
    category="analyzer|fa",
    channels=["try"],
    properties={"new_workflow_enabled": False},
    notifies=None,
    on_cq=True,
    location_regexp=[
        ".+/[+]/DEPS",
        ".+/[+]/pkg/analysis_server/.+",
        ".+/[+]/pkg/analysis_server_client/.+",
        ".+/[+]/pkg/analyzer/.+",
        ".+/[+]/pkg/analyzer_plugin/.+",
        ".+/[+]/pkg/front_end/.+",
        ".+/[+]/pkg/_fe_analyzer_shared/.+",
        ".+/[+]/pkg/meta/.+",
        ".+/[+]/pkg/telemetry/.+",
    ])
dart_ci_sandbox_builder(
    "analyzer-analysis-server-linux",
    category="analyzer|as",
    channels=ANALYZER_CHANNELS,
    on_cq=True)
dart_ci_sandbox_builder(
    "analyzer-linux-release",
    category="analyzer|l",
    on_cq=True,
    channels=ANALYZER_CHANNELS)
dart_ci_sandbox_builder(
    "analyzer-mac-release",
    category="analyzer|m",
    dimensions=mac(),
    channels=ANALYZER_CHANNELS)
dart_ci_sandbox_builder(
    "analyzer-win-release",
    category="analyzer|w",
    dimensions=windows(),
    channels=ANALYZER_CHANNELS)

# sdk
dart_ci_builder("dart-sdk-linux", category="sdk|l", channels=CHANNELS)
dart_ci_builder(
    "dart-sdk-mac", category="sdk|m", channels=CHANNELS, dimensions=mac())
dart_ci_builder(
    "dart-sdk-win",
    category="sdk|w",
    channels=CHANNELS,
    dimensions=windows(),
    on_cq=True)

# ddc
dart_ci_sandbox_builder(
    "ddc-linux-release-chrome",
    category="ddc|l",
    location_regexp=to_location_regexp(DDC_PATHS),
    on_cq=True)
dart_ci_sandbox_builder(
    "ddc-nnbd-linux-release-chrome", category="ddc|nn", channels=["try"])
dart_ci_sandbox_builder(
    "ddc-mac-release-chrome", category="ddc|m", dimensions=mac())
dart_ci_sandbox_builder(
    "ddc-win-release-chrome", category="ddc|w", dimensions=windows())
dart_ci_sandbox_builder("ddk-linux-release-firefox", category="ddc|fl")

# pkg
dart_ci_sandbox_builder("pkg-linux-release", category="pkg|l", on_cq=True)
dart_ci_sandbox_builder("pkg-mac-release", category="pkg|m", dimensions=mac())
dart_ci_sandbox_builder(
    "pkg-win-release", category="pkg|w", dimensions=windows())
dart_ci_sandbox_builder("pkg-linux-debug", category="pkg|ld", channels=["try"])

# misc
dart_ci_sandbox_builder(
    "gclient",
    recipe="gclient",
    category="misc|g",
    properties={"new_workflow_enabled": False},
    on_cq=True)
dart_ci_builder(
    "debianpackage-linux",
    category="misc|dp",
    channels=RELEASE_CHANNELS,
    notifies="infra")
dart_ci_builder(
    "versionchecker-linux", category="misc|vc", channels=RELEASE_CHANNELS)

# external
dart_ci_builder(
    "google", recipe="external", category="external|g", enabled=False, fyi=True)

# infra
dart_ci_builder(
    "base",
    recipe="forward_branch",
    schedule="with 10m interval",
    notifies="infra")
dart_ci_builder(
    "chocolatey", recipe="chocolatey", enabled=False, dimensions=windows())
dart_ci_builder("co19-roller", recipe="package_co19", enabled=False)
dart_ci_builder("docker", recipe="docker", enabled=False)
dart_ci_builder(
    "linearize-flutter",
    recipe="linearize",
    properties={
        "repo": "https://dart.googlesource.com/linear_sdk_flutter_engine.git"
    },
    notifies="infra",
    triggered_by=[
        "dart-gitiles-trigger-master", "dart-flutter-engine-trigger",
        "dart-flutter-flutter-trigger"
    ],
    triggering_policy=scheduler.greedy_batching(max_batch_size=1),
)

# Fuzz testing builders
dart_ci_sandbox_builder(
    "fuzz-linux",
    channels=[],
    notifies="dart-fuzz-testing",
    properties={"new_workflow_enabled": False},
    schedule="0 3,4 * * *")

# Try only builders
dart_try_builder("cl-linux")
dart_try_builder("cl-mac", dimensions=mac())
dart_try_builder("cl-win", dimensions=windows())
dart_try_builder("benchmark-linux", on_cq=True)


def add_postponed_alt_console_entries():
    for entry in postponed_alt_console_entries:
        luci.console_view_entry(console_view="alt", **entry)


add_postponed_alt_console_entries()

# Flutter consoles
luci.console_view_entry(
    builder="flutter-analyze",
    short_name="fa",
    category="analyzer",
    console_view="flutter",
)

luci.console_view_entry(
    builder="flutter-frontend",
    short_name="fl",
    category="fasta",
    console_view="flutter",
)

luci.console_view_entry(
    builder="flutter-engine-linux",
    short_name="3H",
    category="flutter",
    console_view="flutter-hhh",
)
