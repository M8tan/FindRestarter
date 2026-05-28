Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try{
    Import-Module "activedirectory" -ErrorAction Stop
} catch {
    [void]([System.Windows.Forms.MessageBox]::Show("Can't load AD module - $($_.exception.message)", "Sorry!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error))
    return  
}

function Validate-User{
    [CmdletBinding()]
    param(
    [string]$Username,
    [string[]]$Domains
    )
    $UserFullObject = $null
    if (-not $Domains){throw "No domains found"}
    foreach($Domain in $Domains){
    try {
        $UserFullObject = Get-ADUser -Identity $Username -Server $Domain -Properties * -ErrorAction Stop
        if ($UserFullObject){return $UserFullObject}
    } catch {}
    }
    if (-not $UserFullObject){
        throw "User $($Username) not found in all of $($Domains -join ", ")"
    } 
}
function Get-Restarter{
    [CmdletBinding()]
    param(
        [string[]]$Domains
    )
    try{
        $Event = Get-WinEvent -FilterHashtable @{LogName='System';ID=1074} -MaxEvents 1
    } catch {
        throw "Could not find a restart event - $($_.exception.message)"
    }
    if (-not $Event){throw "No event found"}
    try {
        $Restarter = Validate-User -Username $Event.UserID -Domains $Domains -ErrorAction Stop
    } catch {
        throw "Could not get restarter - $($_.exception.message)"
    }
    return $Restarter
}

function Log-Action{
    [CmdletBinding()]
    param(
        [string]$OperatorName,
        [string]$Message
    )
    try{
        $Time = Get-Date -Format "dd/MM/yyyy HH:mm:ss" -ErrorAction Stop
    } catch {
        throw "Can't get a date {relatable} - $($_.exception.message)"
    }
    try {
        "$($Time) | $($env:COMPUTERNAME)\$($OperatorName) | $($Message)" | Out-File -FilePath ".\FindRestarterLogs.log" -Encoding utf8 -Append -Confirm:$false -Force -ErrorAction Stop
    } catch {
        throw "Can't write to file - $($_.exception.message)"
    }
}

try {$Domains = (Get-ADForest -ErrorAction Stop).domains} catch {[void]([System.Windows.Forms.MessageBox]::Show("Can't get domains - $($_.exception.message)", "Sorry!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)); return}
try{$Restarter = Get-Restarter -Domains $Domains -ErrorAction Stop} catch {[void]([System.Windows.Forms.MessageBox]::Show("Can't get restarter - $($_.exception.message)", "Sorry!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)); return}
$Operator = Validate-User -Username $env:USERNAME -Domains $Domains -ErrorAction SilentlyContinue
if($Operator -eq $null){$Operator = @{Name = "Unknown guest"; SamAccountName = $env:USERNAME}}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Find Latest Restarter - current operator: $($Operator.SamAccountName)"
$Form.Size = New-Object System.Drawing.Size(500,350)
$Form.StartPosition = "CenterScreen"

$OutputTB = New-Object System.Windows.Forms.RichTextBox
$OutputTB.Location = New-Object System.Drawing.Point(20,100)
$OutputTB.Size = New-Object System.Drawing.Size(440,180)
$OutputTB.Multiline = $true
$OutputTB.ScrollBars = "Vertical"
$OutputTB.ReadOnly = $true
$OutputTB.Font = New-Object System.Drawing.font("arial", 12,  [System.Drawing.FontStyle]::Bold)
$OutputTB.Text = "The last person to restart $($env:COMPUTERNAME) was...`r`n$($Restarter.Name)`r`nDo you want to disable this user?`r`nOf course, I would advise you to always be merciful, compassionate and forgiving.`r`n`r`nHowever, it's only a click of a button away"

$DisableButton = New-Object System.Windows.Forms.Button
$DisableButton.Text = "Disable"
$DisableButton.Location = New-Object System.Drawing.Point(70,40)
$DisableButton.Width = 70
$DisableButton.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)

$ConfirmDisableButton = New-Object System.Windows.Forms.Button
$ConfirmDisableButton.Text = "Confirm"
$ConfirmDisableButton.Width = 70
$ConfirmDisableButton.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)
$ConfirmDisableButton.Visible = $false
$ConfirmDisableButton.TabStop = $false

$ForgiveButton = New-Object System.Windows.Forms.Button
$ForgiveButton.Text = "Forgive"
$ForgiveButton.Location = New-Object System.Drawing.Point(340,40)
$ForgiveButton.Width = 70
$ForgiveButton.Font = New-Object System.Drawing.font("arial", 10,  [System.Drawing.FontStyle]::Bold)

$DisableButton.add_click({
    $OutputTB.Clear()
    try {
        $RandomX = Get-Random -Minimum 150 -Maximum 300 -ErrorAction Stop
        $RandomY = Get-Random -Minimum 10 -Maximum 80 -ErrorAction Stop
    } catch {
        $OutputTB.AppendText("Error getting confirmation button coordinates - $($_.exception.message)")
        return
    }
    try {
        Log-Action -OperatorName $Operator.SamAccountName -Message "$($Operator.SamAccountName) initiated the disabling of $($Restarter.SamAccountName)" -ErrorAction Stop
    } catch {
        $OutputTB.AppendText("Failed to log actions.`r`n$($_.exception.message)")
        return
    }
    $ConfirmDisableButton.Location = New-Object System.Drawing.Point($RandomX, $RandomY)
    $OutputTB.AppendText("Are you sure?`r`nPlease confirm your actions")
    $ConfirmDisableButton.Visible = $true

})

$ConfirmDisableButton.add_click({
    $OutputTB.Clear()
    try {
        Disable-ADAccount -Identity $Restarter -Confirm:$false -ErrorAction Stop
        Log-Action -OperatorName $Operator.SamAccountName -Message "$($Operator.SamAccountName) disabled $($Restarter.SamAccountName)" -ErrorAction Stop
    } catch {
        $OutputTB.AppendText("An error occured -`r`n$($_.exception.message)")
        Log-Action -OperatorName $Operator.SamAccountName -Message "$($Operator.SamAccountName) failed to disable $($Restarter.SamAccountName) - $($_.exception.message)" -ErrorAction SilentlyContinue
        return
    }
    $ForgiveButton.Visible = $false
    $DisableButton.Visible = $false
    $ConfirmDisableButton.Visible = $false
    $OutputTB.AppendText("OK $($Operator.Name), you're a funny person :)`r`nDisabled $($Restarter.Name)")
})

$ForgiveButton.add_click({
    $OutputTB.Clear()
    $ConfirmDisableButton.Visible = $false
    $OutputTB.AppendText("OK $($Operator.Name), you're a 'nice person'`r`nLeaving the restarter unharmed")
})

$Form.Controls.AddRange(@($DisableButton, $ConfirmDisableButton, $ForgiveButton, $OutputTB))

[void]$Form.ShowDialog()