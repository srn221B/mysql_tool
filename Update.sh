#!/bin/bash

#ファイルが存在するか
File(){
	SQLFILE="$1.sql"
	if [ -f $SQLFILE ]
       	then
		echo "${SQLFILE}に追記していきます"
	else
		echo "${SQLFILE}を新規作成"
	fi
}
#ユーザー新規作成・変更
Change(){
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
Account(){
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
Connect(){
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
Show_DB(){
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
Show_Table(){
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
#テーブルデータを返す(引数:データベース名 テーブル名)
Show_TableData(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;SHOW COLUMNS FROM $2"`
	if [ $? -gt 0 ]
	then
		echo "存在しないテーブル名です"
		echo "最初からやり直してください"
		exit 1
	fi
	echo "/* ${2}テーブルデータ一覧 */"
	mysql --defaults-extra-file=./$file -u $USER -e "use $1;SELECT * FROM $2"
}
#配列の中身を縦に表示
Show_array(){
	local e
	unset ARRAY[0]	
	for e in "${ARRAY[@]}"
	do
		echo "*** ${e}"
	done
}
#更新条件情報を配列に格納(引数:データベース名,テーブル名)
Target_inf(){	
	echo "/* WHERE内容作成 */"
	local update_colum
	local update_data
	read -p "更新条件項目名[exit:q] : " update_colum
	#qの場合終了
	while [ "$update_colum" != "q" ]
	do
		Check_colum $1 $2 $update_colum
		read -p "更新条件項目内容 : " update_data
		#更新条件項目名と内容を配列に追加
		ARRAY4+=("$update_colum")
	       	ARRAY4+=("$update_data")
		read -p "更新条件項目名[exit:q] : " update_colum
	done
	#ARRAY4が空の場合終了
	if [ ${#ARRAY4[@]} -eq 0 ]
	then
		echo "全項目内容を更新します"
	fi
}
#更新情報を配列に格納(引数:データベース名,テーブル名)
Update_inf(){	
	echo "/* SET内容作成 */"
	local update_colum
	local update_data
	read -p "更新項目名[exit:q] : " update_colum
	#qの場合終了
	while [ "$update_colum" != "q" ]
	do
		Check_colum $1 $2 $update_colum
		read -p "更新内容 : " update_data
		#更新項目名と内容を配列に追加
		ARRAY3+=("$update_colum")
	       	ARRAY3+=("$update_data")
		read -p "更新項目名[exit:q] : " update_colum
	done
	#ARRAY3が空の場合終了
	if [ ${#ARRAY3[@]} -eq 0 ]
	then
		echo "更新項目１つ以上は必要です"
		echo "最初からやり直してください"
		exit 1
	fi
}
#存在する項目名かチェック(引数:データベース名,テーブル名,項目名)
Check_colum(){
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
#更新対象情報を入力（引数：データベース名,テーブル名,SQLFILE名）
Create_sql(){
	local e
	local targ_sql
	local data_sql
	local i=0
	#SET組み立て
	for e in "${ARRAY3[@]}"
	do
		if [ $i -eq 0 ]
		then
			targ_sql=" SET ${ARRAY3[i]} = \"${ARRAY3[i+1]}\""
		else
			targ_sql="$targ_sql,${ARRAY3[i]} = \"${ARRAY3[i+1]}\""
		fi
		i=$(( $i + 2 ))
		#配列要素最大か
		if [ $i -eq ${#ARRAY3[@]} ]
		then
			break
		fi
	done
	i=0
	#WHERE
	for e in "${ARRAY4[@]}"
	do
		if [ $i -eq 0 ]
		then
			data_sql=" WHERE ${ARRAY4[i]} = \"${ARRAY4[i+1]}\""
		else
			data_sql="$data_sql AND ${ARRAY4[i]} = \"${ARRAY4[i+1]}\""
		fi
		i=$(( $i + 2 ))
		#配列要素最大か
		if [ $i -eq ${#ARRAY4[@]} ]
		then
			break
		fi
	done
	{ echo "use $1;"
		echo "UPDATE $2$targ_sql$data_sql;"
	} >> $3
}


echo "SQLファイルを新規作成(UPDATE)"
read -p "ファイル名を入力 : " SQLFILE </dev/tty
File $SQLFILE
Account
Connect
Show_DB
read -p "データベース名を入力：" Show_DB </dev/tty
Show_Table $Show_DB
read -p "テーブル名を入力 : " Show_Table </dev/tty
Show_TableData $Show_DB $Show_Table
Target_inf $Show_DB $Show_Table
Update_inf $Show_DB $Show_Table
Create_sql $Show_DB $Show_Table $SQLFILE
echo "-------------------"
echo "ファイル名：$SQLFILE"
cat $SQLFILE

