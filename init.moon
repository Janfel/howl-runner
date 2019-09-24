import Buffer from howl
import File, Process from howl.io
import ProcessBuffer from howl.ui


runner_mt =
  __index:
    shell: howl.sys.env.SHELL or '/bin/sh'
    write_stdin: true
    read_stdout: true
    read_stderr: true

  __call: (code) =>
    -- Preparing the Process.
    local tmpf
    if @tmpfile
      @write_stdin = false
      tmpf = File.tmpfile!
      tmpf.contents = code
      @cmd = @cmd\gsub '#f', tostring(tmpf)

    -- Running the Process.
    proc = Process @
    if proc.stdin
      proc.stdin\write code
      proc.stdin\close!

    -- The Process is running.
    if @bufmode or @quiet
      out, err = proc\pump!

      log_msg = "=> Command '#{proc.command_line}' terminated (#{proc.exit_status_string})"
      log_msg ..= ': '..err if proc.exit_status != 0 and not err.is_blank
      log[proc.exited_normally and 'info' or 'warn'] log_msg

      if @bufmode -- Output into new Buffer.
        buf = with Buffer howl.mode.by_name @bufmode
          .text = out
          .title = proc.command_line
          .modified = false
        howl.app\add_buffer buf

    else -- Run in ProcessBuffer.
      buf = ProcessBuffer proc
      howl.app\add_buffer buf
      howl.app.editor.cursor\eof!
      buf\pump!

    -- The Process has exited.
    tmpf\delete! if tmpf

to_runner = (cmd) -> setmetatable {
  :cmd
  quiet: cmd\urfind '#q'
  tmpfile: cmd\urfind '#f'
  bufmode: cmd\umatch '#b:(%g+)'
}, runner_mt


howl.config.define
  name: 'run_command'
  description: 'The shell command used to execute code by the run command'
  type_of: 'string'
  default: 'cat -'

for mode_name, command in pairs bundle_load 'defs'
  mode = howl.mode.by_name mode_name
  howl.config.set_default 'run_command', command, mode.config_layer if mode


run_cmd = (cmd, code) -> to_runner(cmd)(code)

buffer_run_cmd = (cmd) -> run_cmd(cmd, howl.app.editor.buffer.text)

howl.command.register cmd for cmd in *{
  {
    name: 'buffer-run'
    description: 'Executes the current buffer'
    handler: -> buffer_run_cmd howl.app.editor.buffer.mode.config.run_command
  }
  {
    name: 'buffer-run-as'
    description: 'Executes the current buffer with the runner of the chosen mode'
    input: howl.interact.select_mode
    handler: (mode) -> buffer_run_cmd mode.config.run_command
    get_input_text: (result) -> result.name
  }
  {
    name: 'buffer-run-with'
    description: 'Executes an external command with the current buffer as stdin'
    input: howl.interact.read_text
    handler: buffer_run_cmd
    get_input_text: (result) -> result
  }
}

unload = -> howl.command.unregister cmd for cmd in *{
  'buffer-run'
  'buffer-run-as'
  'buffer-run-with'
}

{
  info:
    author: 'Copyright (c) 2019 Jan Felix Langenbach'
    description: 'Execute the code in the current buffer at the press of a button'
    license: 'MIT'
  :unload
}
