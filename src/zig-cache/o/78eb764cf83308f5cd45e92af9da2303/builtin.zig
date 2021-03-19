usingnamespace @import("std").builtin;
/// Deprecated
pub const arch = Target.current.cpu.arch;
/// Deprecated
pub const endian = Target.current.cpu.arch.endian();

/// Zig version. When writing code that supports multiple versions of Zig, prefer
/// feature detection (i.e. with `@hasDecl` or `@hasField`) over version checks.
pub const zig_version = try @import("std").SemanticVersion.parse("0.8.0-dev.1541+96ae451bb");

pub const output_mode = OutputMode.Exe;
pub const link_mode = LinkMode.Dynamic;
pub const is_test = false;
pub const single_threaded = false;
pub const abi = Abi.gnu;
pub const cpu: Cpu = Cpu{
    .arch = .aarch64,
    .model = &Target.aarch64.cpu.cyclone,
    .features = Target.aarch64.featureSet(&[_]Target.aarch64.Feature{
        .@"aes",
        .@"alternate_sextload_cvt_f32_pattern",
        .@"apple_a7",
        .@"arith_bcc_fusion",
        .@"arith_cbz_fusion",
        .@"crypto",
        .@"disable_latency_sched_heuristic",
        .@"fp_armv8",
        .@"fuse_aes",
        .@"fuse_crypto_eor",
        .@"neon",
        .@"perfmon",
        .@"sha2",
        .@"zcm",
        .@"zcz",
        .@"zcz_fp",
        .@"zcz_fp_workaround",
        .@"zcz_gp",
    }),
};
pub const os = Os{
    .tag = .macos,
    .version_range = .{ .semver = .{
        .min = .{
            .major = 11,
            .minor = 2,
            .patch = 3,
        },
        .max = .{
            .major = 11,
            .minor = 2,
            .patch = 3,
        },
    }},
};
pub const object_format = ObjectFormat.macho;
pub const mode = Mode.Debug;
pub const link_libc = true;
pub const link_libcpp = false;
pub const have_error_return_tracing = true;
pub const valgrind_support = false;
pub const position_independent_code = true;
pub const position_independent_executable = true;
pub const strip_debug_info = false;
pub const code_model = CodeModel.default;
