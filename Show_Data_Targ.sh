#!/bin/bash

#ユーザー新規作成・変更
function Change(){
        local file=".my.cnf"
	local username
	local password
	local hostname
	echo "ユーザーを新規作成・変更"
	read -p "ユーザー名 : " username </dev/tty
	read -s -p "パスワード : " password </dev/tty
	echo
	read -p "ホスト名 : " hostname </dev/tty
	#ファイル内にかきこみ
	{ echo "[client]";
		echo "user = $username";
		echo "password = $password";
		echo "host = $hostname";
	} > $file
	echo "新規作成・変更完了"
}

#ログインユーザー選ぶ
function Account(){
	local file=".my.cnf"
	local login_user
	if [ ! -e $file ]
	then
		Change
	fi
	echo "/* ログインユーザー */"
	cat $file | grep 'user = ' | awk '{print $3}'
	read -p"ユーザー名を指定[変更:change] : " login_user </dev/tty
	if [ "$login_user" = "change" ]
	then
		Change
		Account
	else
		USER="$login_user"
	fi

}
#MYSQL接続テスト
function Connect(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e"select user();"`
	if [ $? -eq 1 ]
       	then
                echo "MYSQLに接続できませんでした。"
                exit 1
	else
		echo "MYSQLに接続できました"
		local user_list=`echo $ret | awk '{ print $2; }'`
		echo "${user_list}でログインしました"
        fi
}

#所有のDBを返す
function Show_DB(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "show databases;"`
	if [ $? -gt 0 ]
	then
		exit 0
	fi
	echo "/* データベース一覧 */"
	ARRAY=($ret)
	Show_array
}
#所有のテーブルを配列に格納しShow_arrayを呼ぶ（引数：データベース名）
function Show_Table(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;show tables;"`
	if [ $? -gt 0 ]
       	then
		echo "存在しないデータベース名です"
		echo "最初からやり直してください"
		exit 1
	fi
	ARRAY=($ret)
	echo "/* ${1}内のテーブル一覧 */"
	Show_array
}
#配列の中身を縦に表示
function Show_array(){
	local e
	unset ARRAY[0]	
	for e in "${ARRAY[@]}"
	do
		echo "*** ${e}"
	done
}
#テーブル情報を返す(引数:データベース名 テーブル名)
function Show_TableData(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;SELECT * FROM $2"`
	if [ $? -gt 0 ]
       	then
		echo "存在しないテーブル名です"
		echo "最初からやり直してください"
		exit 1
	fi
	echo "/* ${2}内のデータ一覧 */"
	mysql --defaults-extra-file=./$file -u $USER -e "use $1;SELECT * FROM $2"
}
#項目がテーブルに存在するかチェック（引数：データベース名，テーブル名，項目名）
function Check_Colum(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;SELECT $3 FROM $2;"`
	if [ $? -gt 0 ]
	then
		echo -e "存在しない項目名です\n最初からやり直してください"
		exit 1
	fi
}
#SQL実行・表示（引数：データベース名，テーブル名，項目名，項目内容）
function Exec_SQL(){
	local file=".my.cnf"
	local ret
	echo -e "use $1;\nSELECT * FROM $2 WHERE $3 = '$4';\nを実行した結果"
	mysql --defaults-extra-file=./$file -u $USER -e "use $1;SELECT * FROM $2 WHERE $3 = '$4';"
}

echo "テーブル内のデータを表示(WHERE指定)"
Account
Connect
Show_DB
read -p "データベース名を入力 : " Show_DB </dev/tty
Show_Table $Show_DB
read -p "テーブル名を入力 : " Show_Table </dev/tty
Show_TableData $Show_DB $Show_Table
read -p "条件項目名を入力：" where </dev/tty
Check_Colum $Show_DB $Show_Table $where
read -p "条件項目内容を入力：" where2 </dev/tty
echo -e "---------------------"
Exec_SQL $Show_DB $Show_Table $where $where2

