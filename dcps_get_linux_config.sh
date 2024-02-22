#!/bin/bash
################
# Scripts name : get_linux_config.sh
# Usage        : ./get_linux_config.sh
# Description  : RHEL情報取得スクリプト
# Modify       :
################

# 変数設定
today=$(date "+%Y%m%d-%H%M%S")                  # ログ出力日時
file_path="./$(uname -n)_config_${today}.log"   # ログファイル名

# 標準出力先をコンソールとファイルに変更
exec > >(tee ${file_path}) 2>&1

# 関数名: タイトル表示関数
# 引数1: タイトル文字列
show_title(){
    title=$1
    echo "################################"
    echo "$1"
    echo "################################"
    echo ""
}

# 関数名: コマンド実行ログ取得関数
# 引数1: 実行コマンド(引数のコマンドで$を利用する場合はエスケープ(\$)すること)
get_command(){
    command=$1
    echo "(command)# ${command}"
    eval "${command}"
    if [ $? -ne 0 ]; then
        echo "[ERROR] コマンド実行エラー。Command: ${command}"
    fi
    echo ""
}

# 関数名: 設定ファイル取得関数(コメント、空行削除)
# 引数1: ファイルパス
get_config(){
    config_file=$1
    echo "(config)# ${config_file}"
    find ${config_file} -type f -or -type l > /dev/null 2>&1 
    if [ $? -eq 0 ]; then
        cat ${config_file} | grep -v -e '^[ ]*#' -e '^[ ]*$'
    else
        echo "[ERROR] ファイルが存在しません。File name: ${config_file}"
    fi
    echo ""
}

# 関数名: 設定ディレクトリ取得関数(コメント、空行削除)
# 引数1: ディレクトリパス
get_config_files(){
    config_dir=$1
    echo "(config_files)# ${config_dir}"
    find ${config_dir} -type d > /dev/null 2>&1 
    if [ $? -eq 0 ]; then
        get_command "ls -l ${config_dir}"
        # ディレクトリ内のファイル及びシンボリックリンクを表示
        for i in $(find ${config_dir} -type f -or -type l | sort) ; do
            echo "(config)# $i"
            cat $i | grep -v -e '^[ ]*#' -e '^[ ]*$'
            echo ""
        done
    else
        echo "[ERROR] ディレクトリが存在しません。Directory name: ${config_dir}"
        echo ""
    fi
}

# 関数名: パッケージインストール状況確認
# 引数1: パッケージ名の先頭文字
check_install_package(){
    package_name=$1
    rc=1

    if [ "$(rpm -qa | grep -c -e "^${package_name}-[0-9]")" -ne 0 ]; then
        rc=0
    else
        echo "[WARN] パッケージがインストールされていません。Package: ${package_name}"
        echo ""
    fi

    return ${rc}
}

# メイン処理
show_title "情報取得開始 $(date '+%Y/%m/%d %H:%M:%S')"

show_title "2 稼働環境情報"

show_title "ホスト名・OSバージョン情報"
get_command "uname -n"
get_command "uname -a"
get_command "uname -r"
get_config "/etc/redhat-release"
get_command "uptime"

show_title "ハードウェア情報"
get_config　"/proc/cpuinfo"
get_config "/proc/meminfo"
## get_command "lspci" PCデバイス情報　省略

show_title "3 OSセットアップ"

show_title "3.2 カーネルパラメータ"
get_command "sysctl -a"
get_config "/etc/sysctl.conf"
get_config_files "/etc/sysctl.d/"
get_command "ulimit -a"
get_config "/etc/security/limits.conf"

show_title "OS言語設定"
get_command "localectl status"
get_command "localectl list-locales"
get_config "/etc/locale.conf"

show_title "3.3 OS基本設定"
get_config "/etc/default/grub"
get_config "/etc/kdump.conf"
get_config "/etc/selinux/config"
get_config "/etc/systemd/system.conf"
get_config "/etc/systemd/journald.conf"

show_title "ディスク設定"
get_command "ls -l /dev/?da*"
get_command "ls -l /dev/mapper/*"
get_command "fdisk -l"
get_command "parted -l"
# 警告メッセージ出力抑制のため2>&-を記載
# https://access.redhat.com/ja/solutions/3189852
get_command "pvdisplay 2>&-"
get_command "vgdisplay 2>&-"
get_command "lvdisplay 2>&-"
get_command "lsblk"
get_command "df -h"
get_command "df -ah"
get_config "/etc/fstab"
get_command "ls -l /"

show_title "4 OSの構成"
show_title "4.1,4.2 アカウント,アカウント設定(ユーザ・グループ設定)"
get_config "/etc/passwd"
get_config "/etc/group"
get_config "/etc/sudoers"
get_config "/etc/nsswitch.conf"

show_title "4.3 ネットワーク設定(IP設定,DNS情報)"
get_command "ip a"
get_command "ip r"
get_command "nmcli d s"
get_command "nmcli c s"
get_command "for i in \$(nmcli c s | grep -v 'NAME ' | cut -d' ' -f1) ; do nmcli c s \$i | cat ; done"
get_config "/etc/resolv.conf" # 名前解決設定ファイル
get_config "/etc/hosts"
get_config_files "/etc/sysconfig/network-scripts/"

show_title "4.4 環境設定"
get_config "/etc/selinux/config"

# show_title "yumパッケージ設定"
get_config_files "/etc/yum.repos.d/"
get_command "rpm -qa"

show_title "4.4.4.1 logrotate設定"
get_config "/etc/logrotate.conf"
get_config_files "/etc/logrotate.d/"

show_title "4.4.4.2 crontab設定"
get_config "/etc/crontab"

show_title "4.4.5 sshd設定"
get_config "/etc/ssh/sshd_config"
get_config "/etc/ssh/ssh_config"

show_title "4.4.6 その他"
show_title "4.4.6.1 aliases"
get_config "/etc/aliases"

show_title "4.4.6.2 hosts.allow"
get_config "/etc/hosts.allow"

show_title "4.4.6.3 hosts.deny"
get_config "/etc/hosts.deny"

show_title "5 メール Postfix設定"
check_install_package "postfix"
if [ $? -eq 0 ]; then
    get_config "/etc/postfix/main.cf"
    get_config "/etc/postfix/header_checks.cf"
    get_config "/etc/postfix/master.cf"
    get_config "/etc/postfix/transport"
    get_config "/etc/postfix/vdomains"
    get_config "/etc/postfix/virtual"
    get_config "/etc/postfix/vmailbox"
    get_command "postconf"
fi

show_title "6 Squid設定"
check_install_package "squid"
if [ $? -eq 0 ]; then
    get_config "/etc/squid/squid.conf"
    get_config "/etc/squid/whitelist"
fi

show_title "7 タイムサーバ 時刻設定"
check_install_package "chrony"
if [ $? -eq 0 ]; then
    get_config "/etc/chrony.conf"
    get_command "chronyc sources"
fi
get_command "timedatectl -a"

show_title "8 サービス稼働状況、設定"
get_command "systemctl list-unit-files --no-page"
get_command "systemctl list-units --no-page"

show_title "Apache (httpd) 設定"
check_install_package "httpd"
if [ $? -eq 0 ]; then
    get_config "/etc/httpd/conf/httpd.conf"
    get_config_files "/etc/httpd/conf.d/"
fi

show_title "Zabbix Agent設定"
check_install_package "zabbix-agent"
if [ $? -eq 0 ]; then
    get_config "/etc/zabbix/zabbix_agentd.conf"
fi

# メイン処理終了
show_title "情報取得終了 $(date '+%Y/%m/%d %H:%M:%S')"
exit 0
