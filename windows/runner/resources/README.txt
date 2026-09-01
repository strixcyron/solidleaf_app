This folder should contain the Windows application icon used by the native runner.

Please copy your ICO file here and name it exactly:
  app_icon.ico

Example:
  C:\path\to\project\windows\runner\resources\app_icon.ico

The resource script (Runner.rc) already references "resources\\app_icon.ico" so placing the ICO here is sufficient.

If you provided an ICO at:
  assets/images/launcher_icon.ico

You can copy it with a command (PowerShell):

  Copy-Item -Path "assets\images\launcher_icon.ico" -Destination "windows\runner\resources\app_icon.ico"

Or manually via Explorer.
