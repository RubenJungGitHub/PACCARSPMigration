# Start-MtHLocalPowerShell -settingfile $settingfile

FUNCTION TO RUN AT THE START OF EVERY POWERSHELL SCRIPT for Loading and validating the SETTINGS. this module (BASICMODULE) should be in the PSModulePath

### $settings is loaded, validated and returned with this command

The main goal of this function is to group all validation of the settings in one place.

### $Settings.FilePath checks:
- [ ] if "SettingSchemaFile" is in the FilePath property then the settingsfile is checked against this schema.
- [ ] checks for all values in $settings.FilePath if the path does exist.
- [ ] checks if "SettingFile" is correct and if not it updates it.

### Used Modules are loaded, reloaded
- [ ] Reload all modules in $Settings.StartUp.LocalModules (By removing them and importing. This is done for code changes)
- [ ] Load all modules in $Settings.StartUp.ImportModules
- [ ] Load all modules in $Settings.StartUp.ImportModulesWindows in Windows Mode (for PowerShell Core)

### Verbose switching, Version and elevation checking
Other $Settings.StartUp Checks
- [ ] verbose = $TRUE dan startup will be done in verbose mode.
- [ ] Check if the powershell version is at least PSVersion (if present)
- [ ] Check if powershell is running 32 or 64 bit and if it matches the "needs64bit" setting
- [ ] Check if powershell is running in elevated mode and if it matches the "elevated" setting

This function returns an object will all settings in this settingfile.

### Other settingscheck functions
The function **Initialize-MtHSharePoint** in SharePointAutomation is checking environment and environmentdetails. Not all scripts need those checks.

