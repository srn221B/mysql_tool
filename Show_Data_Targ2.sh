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
	if [ $? -eq 1 ];
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
	unset ARRAY[0]
	Show_array
}
#所有のテーブルを返す（引数：データベース名）
function Show_Table(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;show tables;"`
	if [ $? -gt 0 ];
       	then
		echo "存在しないデータベース名です"
		echo "最初からやり直してください"
		exit 1
	fi
	echo "/* テーブル一覧 */"
	ARRAY=($ret)
	unset ARRAY[0]
	Show_array
}
#存在するテーブル名かチェック(引数:データベース名,テーブル名)
function Check_table(){
	local ret
	local file=".my.cnf"
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;select * FROM $2;"`
        if [ $? -gt 0 ]
       	then
                echo "存在しないテーブル名です"
                echo "最初からやり直してください"
                exit 1
        fi
}
#存在する項目名かチェック(引数:データベース名,テーブル名,項目名)
function Check_colum(){
	local ret
	local file=".my.cnf"
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;select $3 FROM $2;"`
        if [ $? -gt 0 ]
	then
                echo "存在しない項目名です"
                echo "最初からやり直してください"
                exit 1
        fi
}
#テーブル情報を返す(引数:データベース名 テーブル名)
function Show_TableInf(){
	local file=".my.cnf"
	local ret
	echo "/* ${2}テーブルの列情報 */"
	mysql --defaults-extra-file=./$file -u $USER -e "use $1;SHOW COLUMNS FROM $2"
}
#テーブルデータを返す(引数:データベース名 テーブル名)
function Show_TableData(){
	local file=".my.cnf"
	local ret
	echo "/* ${2}テーブルデータ一覧 */"
	mysql --defaults-extra-file=./$file -u $USER -e "use $1;SELECT * FROM $2"
}
#配列の中身を１要素目削除し縦に表示
function Show_array(){
	local e	
	for e in "${ARRAY[@]}"
	do
		echo "*** ${e}"
	done
}
#結合条件関数(引数：データベース名、結合テーブル名）
function Targ_Colum(){
	local colum
	Show_TableData $1 $2
	read -p "条件項目名[無し/終了:q]：" colum
	while [ "$colum" != "q" ]
	do
		Check_colum $1 $2 $colum
		TARG_COLUM+=($2)
		TARG_COLUM+=($colum)
		read -p "条件項目内容：" colum
		TARG_COLUM+=($colum)
		read -p "条件項目名[無し/終了:q]：" colum
	done
}
#抽出項目を決める(引数：データーベース名 テーブル名)
function COLUM(){
	local colum
	local cname
	Show_TableInf $1 $2
	echo "集合関数は直接入力"
	read -p "抽出項目名[終了:q]：" colum
	#テーブル内の表示項目を決める
	while [ "$colum" != "q" ]
	do
		#集合関数分別
		if [ "`echo $colum | grep "("`" == "$colum" ]
		then
			AGG_COLUM+=($colum)
			read -p "${colum}項目の表示名[項目名と同一:q]：" cname
			AGG_COLUM+=($cname)
		else
			Check_colum $1 $2 $colum
			SHOW_COLUM+=($colum)
			read -p "${colum}項目の表示名[項目名と同一:q]：" cname
			SHOW_COLUM+=($cname)
		fi
		read -p "抽出項目名[終了:q]：" colum
	done
	#抽出項目判定
	if [ ${#SHOW_COLUM[@]} -eq 0 ] && [ ${#AGG_COLUM[@]} -eq 0 ]
	then
		echo "抽出項目は一つ以上必要です"
		echo "最初からやり直してください"
		exit 1
	fi
}
#SQLをつくる(引数：データベース名,テーブル名）
function Create_sql(){
	local file=".my.cnf"
	FROM="FROM $2"
	SQL_1
	SQL_3
	echo -e "---------------"
	if [ 0 -eq ${#TARG_COLUM[@]} ] && [ 0 -eq ${#AGG_COLUM[@]} ] #条件と集合関数がない場合
	then
		echo -e "use $1;\n$SELECT $FROM;\nを実行した結果"
		mysql --defaults-extra-file=./$file -u $USER -e "use $1;$SELECT $FROM;"
	elif [ 0 -eq ${#TARG_COLUM[@]} ] #条件がない場合
	then
		echo -e "use $1;\n$SELECT $FROM $GROUP;\nを実行した結果"
		mysql --defaults-extra-file=./$file -u $USER -e "use $1;$SELECT $FROM $GROUP;"
	elif [ 0 -eq ${#AGG_COLUM[@]} ] #集合関数がない場合
	then
		echo -e "use $1;\n$SELECT $FROM $WHERE;\nを実行した結果"
		mysql --defaults-extra-file=./$file -u $USER -e "use $1;$SELECT $FROM $WHERE;"
	else
		echo -e "use $1;\n$SELECT $FROM $WHERE $GROUP;\nを実行した結果"
		mysql --defaults-extra-file=./$file -u $USER -e "use $1;$SELECT $FROM $WHERE $GROUP;"
	fi
}
#selectとgroupをつくる
function SQL_1(){
	#抽出項目
	local e
	local i=0
	for e in "${SHOW_COLUM[@]}"
	do
		if [ $i -eq 0 ]
		then
			if [ "${SHOW_COLUM[i+1]}" == "q" ]
			then
				SELECT="SELECT ${SHOW_COLUM[i]}"
				GROUP="GROUP BY ${SHOW_COLUM[i]}"
			else
				SELECT="SELECT ${SHOW_COLUM[i]} AS ${SHOW_COLUM[i+1]}"
				GROUP="GROUP BY ${SHOW_COLUM[i+1]}"
			fi
		else
			if [ "${SHOW_COLUM[i+1]}" == "q" ]
			then
				SELECT="$SELECT, ${SHOW_COLUM[i]}"
				GROUP="$GROUP, ${SHOW_COLUM[i]}"
			else
				SELECT="$SELECT, ${SHOW_COLUM[i]} AS ${SHOW_COLUM[i+1]}"
				GROUP="$GROUP, ${SHOW_COLUM[i+1]}"
			fi
		fi
		i=$(( $i + 2 ))
		#要素数最大
		if [ $i -eq ${#SHOW_COLUM[@]} ]
		then
			break
		fi
	done
	#集合関数項目
	i=0
	for e in "${AGG_COLUM[@]}"
	do
		#集合関数項目のみの場合
		if [ 0 -eq ${#SHOW_COLUM[@]} ] && [ $i -eq 0 ]
		then
			if [ "${AGG_COLUM[i+1]}" == "q" ]
			then
				SELECT="SELECT ${AGG_COLUM[i]}"
			else
				SELECT="SELECT ${AGG_COLUM[i]} AS ${AGG_COLUM[i+1]}"
			fi
		else
			if [ "${AGG_COLUM[i+1]}" == "q" ]
			then
				SELECT="$SELECT, ${AGG_COLUM[i]}"
			else
				SELECT="$SELECT, ${AGG_COLUM[i]} AS ${AGG_COLUM[i+1]}"
			fi
		fi
		i=$(( $i + 2 ))
		#要素数最大
		if [ $i -eq ${#AGG_COLUM[@]} ]
		then
			break
		fi
	done
}
#whereをつくる
function SQL_3(){
	WHERE="WHERE"
	local e
	local i=0
	for e in "${TARG_COLUM[@]}"
	do
		if [ $i -eq 0 ]
		then
			WHERE="$WHERE ${TARG_COLUM[i]}.${TARG_COLUM[i+1]} = \"${TARG_COLUM[i+2]}\""
		else
			WHERE="$WHERE AND ${TARG_COLUM[i]}.${TARG_COLUM[i+1]} = \"${TARG_COLUM[i+2]}\""
		fi
		i=$(( $i + 3 ))
		if [ $i -eq ${#TARG_COLUM[@]} ]
		then
			break
		fi
	done
}

echo "テーブル内のデータを表示(SELECT/WHERE指定)"
Account
Connect
Show_DB
read -p "データベース名を入力：" Show_DB </dev/tty
Show_Table $Show_DB
read -p "テーブル名を入力：" Show_Table </dev/tty
Check_table $Show_DB $Show_Table
Targ_Colum $Show_DB $Show_Table
COLUM $Show_DB $Show_Table
Create_sql $Show_DB $Show_Table

