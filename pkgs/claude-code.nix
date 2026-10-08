{ claude-code }:
claude-code.override {
  manifest = {
    version = "2.1.294";
    platforms = {
      linux-x64 = {
        binary = "claude.zst";
        checksum = "f65567ed6fbf9d4cb670819a9ed00cec415022f93043350b95513a39dbbb0b5f";
      };
      linux-arm64 = {
        binary = "claude.zst";
        checksum = "66c3ea3078271f9c9300f4f2dae3852d1df57aeb0be6cc15183b3eac6cc6a2d3";
      };
      darwin-arm64 = {
        binary = "claude.zst";
        checksum = "c6265c91743c97af8ad419de8500d5bade86c55691f20aa1c1f243a94381a95c";
      };
    };
  };
}
