# Acer Battery Limit

Extremely lightweight PowerShell script for enabling or disabling Acer Battery Health Mode through the Acer-specific `root\WMI:BatteryControl` interface.

On supported Acer laptops, the firmware normally provides two charging modes:

- **On:** enables the firmware-managed charge limit, normally approximately 80%
- **Off:** disables the charge limit and permits charging to 100%

The script does not run continuously. It starts, sends the selected command to the Acer WMI interface, displays a confirmation or error message, and exits.

> [!IMPORTANT]
> This script cannot set an arbitrary charge percentage. It only switches the Battery Health Mode exposed by the Acer firmware.

## Requirements

- A compatible Acer laptop (tested on Acer Aspire AG15-42P)
- Windows 10 or Windows 11
- Windows PowerShell 5.1
- Administrator privileges
- Acer firmware and drivers exposing:

  ```text
  Namespace: root\WMI
  Class:     BatteryControl
  Method:    SetBatteryHealthControl
  ```

PowerShell 7 is not supported because the script uses `Get-WmiObject`, which is available in Windows PowerShell 5.1.

## Files

```text
AcerBatteryLimit.ps1
README.md
LICENSE
```

## Installation

### 1. Download the script

Download `AcerBatteryLimit.ps1` and review its contents before running it.

### 2. Store it in a protected location

The recommended location is:

```text
C:\Program Files\AcerBatteryLimit\AcerBatteryLimit.ps1
```

To create the folder and copy the script there:

1. Open File Explorer.
2. Navigate to `C:\Program Files`.
3. Create a folder named `AcerBatteryLimit`.
4. Approve the administrator prompt.
5. Copy `AcerBatteryLimit.ps1` into the new folder.

Using `C:\Program Files` is preferable to storing the script on the Desktop when an elevated scheduled task will execute it. Standard non-elevated applications normally cannot modify files there.

## Direct usage

Open **Windows PowerShell 5.1** and run one of the following commands.

### Enable the approximately 80% limit

```powershell
& "C:\Program Files\AcerBatteryLimit\AcerBatteryLimit.ps1" -Action On
```

### Disable the limit and permit charging to 100%

```powershell
& "C:\Program Files\AcerBatteryLimit\AcerBatteryLimit.ps1" -Action Off
```

If the current PowerShell process is not elevated, the script requests administrator privileges through User Account Control.

To launch it explicitly through Windows PowerShell 5.1:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\AcerBatteryLimit\AcerBatteryLimit.ps1" -Action On
```

Replace `On` with `Off` to disable the limit.

## Actions

| Action | Requested firmware setting |
|---|---|
| `On` | Enable Acer Battery Health Mode, normally limiting charging to approximately 80% |
| `Off` | Disable Acer Battery Health Mode and permit charging to 100% |

The `-Action` parameter is mandatory. The script does not provide status or toggle functions because status reporting is not reliable on every supported firmware implementation.

## Avoiding a UAC prompt on every use

The Acer WMI operation may require administrator rights. If running without elevation produces `Access denied`, Windows Task Scheduler can store two predefined elevated tasks. Ordinary shortcuts can then request those tasks without displaying a new UAC prompt each time.

You should approve elevation while creating or modifying the tasks. Do not disable UAC system-wide.

### Task 1: enable the charge limit

1. Open the Start menu and search for **Task Scheduler**.
2. Right-click **Task Scheduler** and select **Run as administrator**.
3. In the right-hand **Actions** panel, select **Create Task...**. Do not select **Create Basic Task...**.
4. On the **General** tab, configure:
   - **Name:** `Acer Battery Limit On`
   - **Security option:** `Run only when user is logged on`
   - Select **Run with highest privileges**.
   - Under **Configure for**, select the applicable Windows version.
5. Leave the **Triggers** tab empty. The task will be started manually by a shortcut.
6. On the **Actions** tab, select **New...** and enter:

   **Program/script:**

   ```text
   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
   ```

   **Add arguments:**

   ```text
   -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\AcerBatteryLimit\AcerBatteryLimit.ps1" -Action On
   ```

   **Start in:**

   ```text
   C:\Program Files\AcerBatteryLimit
   ```

7. On the **Conditions** tab, clear **Start the task only if the computer is on AC power**. Otherwise, Windows may decline to run the task while the laptop is on battery power.
8. On the **Settings** tab:
   - Select **Allow task to be run on demand**.
   - For **If the task is already running**, select **Do not start a new instance**.
9. Select **OK** to save the task.

### Task 2: disable the charge limit

Repeat the procedure above with these differences:

- **Name:** `Acer Battery Limit Off`
- **Add arguments:**

  ```text
  -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\AcerBatteryLimit\AcerBatteryLimit.ps1" -Action Off
  ```

### Test the scheduled tasks

Before creating shortcuts:

1. Find `Acer Battery Limit On` in Task Scheduler Library.
2. Right-click it and select **Run**.
3. Wait for the script to finish.
4. Test `Acer Battery Limit Off` in the same way.

While the script is executing, Task Scheduler displays the task as **Running**. After PowerShell exits, its status returns to **Ready**. A short `Start-Sleep` confirmation delay keeps the task in the Running state for that duration. The task does not remain active after the PowerShell process exits.

If a task remains Running indefinitely, check that:

- the script does not contain `Read-Host`;
- the PowerShell arguments do not contain `-NoExit`;
- the script reaches `exit 0` or `exit 1`; and
- no hidden PowerShell window is waiting for input.

## Create desktop shortcuts

### Shortcut for enabling the limit

1. Right-click an empty area of the Desktop.
2. Select **New > Shortcut**.
3. Enter this target:

   ```text
   C:\Windows\System32\schtasks.exe /run /tn "Acer Battery Limit On"
   ```

4. Select **Next**.
5. Name the shortcut:

   ```text
   Enable 80% charge limit
   ```

6. Select **Finish**.

### Shortcut for disabling the limit

Create another shortcut with this target:

```text
C:\Windows\System32\schtasks.exe /run /tn "Acer Battery Limit Off"
```

Name it:

```text
Disable charge limit
```

Do not enable **Run as administrator** for these two shortcuts. They only request execution of scheduled tasks that are already configured to run with highest privileges.

## Optional shortcut icons

To assign an icon:

1. Right-click the shortcut and select **Properties**.
2. Select **Change Icon...**.
3. Browse to:

   ```text
   C:\Windows\System32\imageres.dll
   ```

4. Choose distinct icons for the `On` and `Off` shortcuts.

## Resource usage

The two scheduled tasks are stored definitions. They do not keep separate PowerShell processes running in the background.

When a shortcut is used:

1. `schtasks.exe` requests the registered task.
2. Task Scheduler starts `powershell.exe` with the selected action.
3. The script sends the WMI command.
4. The script displays its message and waits for any configured delay.
5. PowerShell exits.

During `Start-Sleep`, PowerShell remains in memory but should use negligible CPU time. After it exits, the script consumes no CPU or memory. Acer firmware manages the selected charge mode; the script does not need to remain active.

## Troubleshooting

### `Access denied`

The Acer WMI provider requires administrator privileges on some systems. Run the script as administrator or use the scheduled-task configuration above.

### `BatteryControl` cannot be found

The laptop firmware or installed Acer drivers may not expose the required interface. You can test for the class in an elevated Windows PowerShell 5.1 window:

```powershell
Get-WmiObject -Namespace "root\WMI" -Class "BatteryControl"
```

If PowerShell reports an invalid or unavailable class, this script cannot use the required Acer interface on the current installation.

### Script execution is disabled

Run the script through Windows PowerShell 5.1 with a process-specific execution-policy override:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\AcerBatteryLimit\AcerBatteryLimit.ps1" -Action On
```

Review the script before using `-ExecutionPolicy Bypass`. This option permits execution; it does not make an untrusted script safe.

### A confirmation window closes too quickly

Add or adjust this line before `exit 0`:

```powershell
Start-Sleep -Seconds 5
```

For errors, a longer delay can be placed before `exit 1`, for example:

```powershell
Start-Sleep -Seconds 10
```

### The command completed, but the charging behaviour did not change

The simplified script does not verify the firmware state because status retrieval is not reliable on every system. Its success message means the command was submitted and the WMI method returned a result, not that the resulting battery state was independently confirmed.

Check the result through the relevant Acer utility or by observing charging behaviour over time. A battery already above the selected threshold may not immediately discharge to that threshold.

## Security considerations

The scheduled tasks execute the script with elevated privileges. Keep the script in a location that non-elevated applications cannot normally modify, such as:

```text
C:\Program Files\AcerBatteryLimit
```

Do not place a script executed by an elevated scheduled task in a shared directory or on a writable network location. Do not add credentials, access tokens, serial numbers, or other private information to the repository.

The scheduled-task approach avoids repeated prompts only for the predefined `On` and `Off` commands. Anyone able to invoke these tasks under your Windows account can request those elevated actions.

## Compatibility

Compatibility depends on the laptop model, firmware, BIOS, and installed Acer drivers. The presence of the Acer brand alone does not establish compatibility.

This project is intended only for machines exposing the expected Acer `BatteryControl` WMI interface and method signature.

Confirmed compatible laptops

| Manufacturer | Series | Model | Windows | BIOS | Result | Reported by |
|---|---|---|---|---|---|---|
| Acer | Aspire | AG15-42P | Windows 11 | Not reported | Compatible | Project author |

### Confirmed incompatible laptops

No incompatible models have been reported yet.

### Report your result

Reports from other Acer laptop owners are welcome. Successful and unsuccessful tests are both useful because Acer may use different firmware interfaces across models and BIOS versions.

Before reporting a result, test both commands:

```powershell
.\AcerBatteryLimit.ps1 -Action On
.\AcerBatteryLimit.ps1 -Action Off
```

Then open an issue in this repository with the title:

```text
Compatibility report: Acer <series> <model>
```

Include the following information:

```text
Manufacturer: Acer
Series:
Exact model:
Windows version:
BIOS version:
AcerBatteryLimit action tested: On / Off / Both
Result: Compatible / Incompatible / Partially working
Observed behaviour:
Error message, if any:
```

The exact model and BIOS version can usually be obtained from Windows PowerShell:

```powershell
Get-CimInstance Win32_ComputerSystem |
    Select-Object Manufacturer, Model

Get-CimInstance Win32_BIOS |
    Select-Object SMBIOSBIOSVersion, ReleaseDate
```

Do not include your serial number, Windows product key, user name, computer name, or other personal identifiers.

A model should be added to the compatible list only after both `On` and `Off` have been tested successfully. If the WMI command runs but the charging behaviour cannot be confirmed, report the result as **Partially working**, not compatible.

## Disclaimer

This is an unofficial community project. It is not affiliated with, authorised by, or endorsed by Acer.

The software is provided without warranty. Firmware behaviour varies by device. Review the script before running it and decide whether it is appropriate for your system.

## Acknowledgements

The Acer `BatteryControl` WMI method used by this script was identified from existing open-source work, including:

- [talmidhon/AcerChargeLimiter](https://github.com/talmidhon/AcerChargeLimiter)
- [rafradek/Acer-Predator-Scripts](https://github.com/rafradek/Acer-Predator-Scripts)

Retain any notices required by the licences of code incorporated from other projects.

## Licence

This project is licensed under the MIT License. See [`LICENSE`](LICENSE) for the full licence text.
