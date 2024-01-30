################
# Scripts name : get_windows_config.ps1
# Usage        : ./get_windows_config.ps1
# Description  : Windows情報取得スクリプト
################

$today = (Get-Date).ToString("yyyyMMdd-HHmmss")    # ログ出力日時
$file_path = ".\$(hostname)_config_${today}.log"     # ログファイル名
$encode_file_path = ".\$(hostname)_encode_${today}.tmp"     # 文字化け対策用一時ファイル名
Start-Transcript -Path ${file_path}

# 列挙項目が省略されないようにする
$FormatEnumerationLimit = -1

function show_title($title){
    Write-Output "################################"
    Write-Output "${title}"
    Write-Output "################################"
    Write-Output ""
}

# 関数名: コマンド実行ログ取得関数
# 引数1: 実行コマンド(引数のコマンドで$を利用する場合はエスケープ(`$)すること)
# 引数2: list: リストですべての項目を表示、 list_brief: リストで一部項目を表示、省略: テーブル表示
function get_command($command, $output_format){
    Write-Output "(command)# ${command}"
    if(${output_format} -eq "list"){
        ${command} = ${command} + "| fl *"
    }elseif(${output_format} -eq "list_brief"){
        ${command} = ${command} + "| fl"
    }else{
        # ${command} = ${command} + "| ft -AutoSize -Wrap"
        ${command} = ${command} + "| ft -AutoSize | Out-String -Width 2048"
    }
    try{
        Invoke-Expression "${command}"
    }catch{
        Write-Output "[ERROR] コマンド実行エラー。Command: ${command}"
    }
}

# 関数名: コマンド実行ログ取得関数(コマンドプロンプト用)
# 引数1: 実行コマンド(引数のコマンドで$を利用する場合はエスケープ(`$)すること)
# 引数2: list: リストですべての項目を表示、 list_brief: リストで一部項目を表示、省略: テーブル表示
function get_command_bat($command){
    Write-Output "(command_bat)# cmd /C '${command}'"
    try{
        Invoke-Expression "cmd /C '${command}' | fl"
    }catch{
        Write-Output "[ERROR] コマンド実行エラー。Command: ${command}"
    }
    Write-Output ""
}

# 関数名: 設定ファイル取得関数(コメント、空行削除)
# 引数1: ファイルパス
function get_config($config_file){
    Write-Output "(config)# ${config_file}"
    if(Test-Path "${config_file}"){
        Get-Content ${config_file} | Where-Object { $_ -notmatch "^#" -and $_ -ne "" }
    }else{
        Write-Output "[ERROR] ファイルが存在しません。File name: ${config_file}"
    }
    Write-Output ""
}

# メイン処理
show_title "情報取得開始 $((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))"

show_title "ホスト名・OSバージョン情報"
get_command_bat "hostname"
get_command_bat "whoami.exe /user"
get_command "Get-WmiObject Win32_OperatingSystem | Select-Object Caption, OSArchitecture, Version, CodeSet, CountryCode, LastBootUpTime"

show_title "ハードウェア情報"
get_command "Get-WmiObject Win32_ComputerSystem | Select-Object NumberOfProcessors, NumberOfLogicalProcessors, @{N='TotalPhysicalMemoryGB'; E={[Math]::Round(`$_.TotalPhysicalMemory/1GB, 2)}}" "list"
get_command "Get-PnpDevice | Select-Object Class, FriendlyName, Manufacturer, Status"

show_title "OS基本設定"
get_command "Get-ComputerInfo" "list"
if($null -eq (Get-WmiObject Win32_Pagefile)){
    Write-Output "(config)# すべてのページングファイルのサイズを自動的に管理する"
    Write-Output '有効'
}else{
    Write-Output '無効'
    get_command "Get-WmiObject Win32_Pagefile" "list"
}
Write-Output ""
# DebugInfoTypeは、0:無効、1:完全、2:カーネル、3:最小、7:自動
get_command "Get-WmiObject Win32_OSRecoveryConfiguration" "list"

show_title "ネットワーク設定"
get_command_bat "ipconfig /all"
get_command "Get-NetAdapter" "list"
get_command "Get-NetAdapterAdvancedProperty"
get_command "Get-NetAdapterBinding"
get_command "Get-NetAdapterChecksumOffload"
get_command "Get-NetIPConfiguration" "list"
get_command "Get-NetIPAddress"
get_command "Get-NetRoute"
get_config "C:\Windows\system32\drivers\etc\hosts"
get_command "netsh int ipv4 show dynamicportrange tcp"
get_command "netsh int ipv4 show dynamicportrange udp"
get_command "netsh int ipv4 show excludedportrange tcp"
get_command "netsh int ipv4 show excludedportrange udp"
get_command "netsh winhttp show proxy"

show_title "ディスク設定"
# Windows Server 2022では一度目のGet-Diskの表示がされないことがあるため、2回実行する
Get-Disk | Out-Null; sleep 1; get_command "Get-Disk"
get_command "Get-WmiObject Win32_DiskDrive | Select-Object Index, DeviceID, Model, @{N='SizeGB'; E={[Math]::Round(`$_.Size/1GB, 2)}}, Partitions | sort Index"
get_command "Get-WmiObject Win32_DiskPartition | Select-Object DiskIndex, Index, Name, BlockSize, Bootable, @{N='SizeGB'; E={[Math]::Round(`$_.Size/1GB, 2)}}, Type, Description | sort DiskIndex, Index"
get_command "Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, FileSystem, @{N='SizeGB'; E={[Math]::Round(`$_.Size/1GB, 2)}}, @{N='FreeSpaceGB'; E={[Math]::Round(`$_.FreeSpace/1GB, 2)}}, ProviderName, Description"
get_command "Get-WmiObject Win32_DiskDrive" "list"
get_command "Get-WmiObject Win32_DiskPartition" "list"
get_command "Get-WmiObject Win32_LogicalDisk" "list"
get_command "Get-ChildItem 'C:\' -Hidden"

show_title "光学ドライブ設定"
get_command "Get-WmiObject Win32_CDROMDrive | Select-Object Drive, Caption, Manufacturer, MediaLoaded"

show_title "ユーザ・グループ設定"
get_command "Get-LocalUser | Select-Object Name, Enabled, Description"
get_command "Get-LocalGroup | Select-Object Name, Description"

show_title "リモートデスクトップ設定"
Write-Output "(config)# このコンピュータへのリモート接続を許可する"
if((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections -eq 0){
    Write-Output '許可する'
}else{
    Write-Output '許可しない'
}
Write-Output ""

Write-Output "(config)# ネットワークレベル認証でリモートデスクトップを実行しているコンピューターからのみ接続を許可する (推奨)"
if((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp').UserAuthentication -eq 0){
    Write-Output '無効'
}else{
    Write-Output '有効'
}
Write-Output ""

show_title "時刻設定"
get_command "Get-TimeZone"
get_command_bat "sc qc w32time"
get_command_bat "sc qtriggerinfo w32time"
get_command "Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config'" "list"
get_command "Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'" "list"
get_command "Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient'" "list"
get_command "Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer'" "list"
# w32tmの文字化け対策のため、一時ファイルに出力してから表示
get_command_bat "w32tm /query /status > ${encode_file_path}"
Get-Content "${encode_file_path}"
Remove-Item "${encode_file_path}" -Confirm:$false

show_title "OS言語設定"
get_command "Get-WinSystemLocale"
get_command "Get-Culture" "list"
get_command "Get-WmiObject Win32_Keyboard | Select-Object Name, Layout, Description"

show_title "サービス設定"
get_command "Get-Service | Select-Object Name, DisplayName, Status, StartType"

show_title "役割・機能"
get_command "Get-WindowsFeature"

show_title "更新プログラム"
get_command "Get-HotFix"

show_title "インストールソフトウェア"
# レジストリから抽出。$及び`はエスケープすること(`$、``)
# Get-WmiObject Win32_Productは環境によっては負荷が高いため利用しない
get_command "Get-ChildItem -Path('HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', ``
    'HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', ``
    'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall') | ``
    % { Get-ItemProperty `$_.PsPath | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate }"
# get_command "Get-WmiObject Win32_Product | Select-Object Name, Vendor, Version"

show_title "PowerShellモジュール"
get_command "Get-ChildItem 'C:\Program Files\WindowsPowerShell\Modules'"

show_title "イベントビューアー"
# セキュリティイベントの情報出力は、「管理者で実行」が必要
get_command "Get-EventLog -List | Select-Object Log, LogDisplayName, OverflowAction, MaximumKilobytes"
get_command "Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\System' | Select-Object PrimaryModule, File, MaxSize"
get_command "Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application' | Select-Object PrimaryModule, File, MaxSize"
get_command "Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security' | Select-Object PrimaryModule, File, MaxSize"

show_title "Windows Defenderファイアウォール"
get_command "Get-NetFirewallProfile | Select-Object Name, Enabled"
get_command "Get-NetFirewallRule | Select-Object Name, DisplayName, Enabled | sort Name"

# メイン処理終了
show_title "情報取得終了 $((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))"
Stop-Transcript
exit 0
