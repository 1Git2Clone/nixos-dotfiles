-- DISABLED: the backend it points at does not exist on this machine. The
-- end_point below is Ollama on :11434, but ollama is not in any module here
-- and the binary is not on PATH, so every request curls a dead port and
-- minuet notifies `Request failed with exit code 7` (curl CURLE_COULDNT_CONNECT)
-- once per attempt. `rust` is in auto_trigger_ft, so editing a .rs file floods
-- the message area.
--
-- To re-enable: add ollama to a module, `ollama pull qwen3.5:4b`, confirm
-- `ss -ltnp | grep 11434` listens, then drop the `enabled = false` line.
-- Same disable-in-place pattern as lua/plugins/mason.lua.
return {
  "milanglacier/minuet-ai.nvim",
  enabled = false,
  config = function()
    require("minuet").setup({
      provider = "openai_fim_compatible",
      n_completions = 1,
      context_window = 512,
      request_timeout = 5,
      provider_options = {
        openai_fim_compatible = {
          api_key = "TERM",
          name = "Ollama",
          end_point = "http://localhost:11434/v1/completions",
          model = "qwen3.5:4b",
          optional = {
            max_tokens = 56,
            top_p = 0.9,
          },
        },
      },

      virtualtext = {
        auto_trigger_ft = { "python", "javascript", "lua", "cpp", "rust", "go" },
        keymap = {
          accept = "<A-A>",
          accept_line = "<A-a>",
          accept_n_lines = "<A-z>",
          prev = "<A-[>",
          next = "<A-]>",
          dismiss = "<A-e>",
        },
      },
    })
  end,
}
