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
	echo "/* $1内のテーブル一覧 */"
	Show_array
}

#テーブル情報を返す(引数:データベース名 テーブル名)
Show_TableInf(){
	local file=".my.cnf"
	local ret
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;SHOW COLUMNS FROM $2"`
	if [ $? -gt 0 ]
	then
		echo "存在しないテーブル名です"
		echo "最初からやり直してください"
		exit 1
	fi
	echo "/* $2テーブルの列情報 */"
	mysql --defaults-extra-file=./$file -u $USER -e "use $1;SHOW COLUMNS FROM $2"
	ARRAY_INF=($ret)
	Table_extraction
}
#テーブル内にある入力必須項目を取り出しShow_array2を呼ぶ
Table_extraction(){
	local i=0
	local e
	#ARRAY2用
	local n=0
	for e in "${ARRAY_INF[@]}"
	do
		##NOTNULL && AIの場合
		if [ "${e}" == "NO" ] && [ "${ARRAY_INF[i+3]}" != "auto_increment" ]
		then
			ARRAY2[n]="${ARRAY_INF[i-2]}"
			let n++
		fi
		let i++
	done
	echo "/* 入力必須項目 */"
	Show_array2
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
#配列の中身を横に表示
Show_array2(){	
	local e
	local data
	for e in "${ARRAY2[@]}"
	do
		data="$data ${e}"
	done
	echo $data
}

#追加情報を配列に格納(引数:データベース名,テーブル名)
Insert_inf(){	
	local insert_colum
	local insert_data
	read -p "追加項目名[exit:q] : " insert_colum
	#qの場合終了
	while [ "$insert_colum" != "q" ]
	do
		Check_colum $1 $2 $insert_colum
		read -p "追加内容 : " insert_data
		#追加項目名と内容を配列に追加
		ARRAY3+=("$insert_colum")
	       	ARRAY3+=("$insert_data")
		read -p "追加項目名[exit:q] : " insert_colum
	done
	#ARRAY3が空の場合終了
	if [ ${#ARRAY3[@]} -eq 0 ]
	then
		echo "追加項目１つ以上は必要です"
		echo "最初からやり直してください"
		exit 1
	fi
}


#存在する項目名かチェック(引数:データベース名,テーブル名,項目名)
Check_colum(){
	local ret
	local file=".my.cnf"
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;select $3 FROM $2;"`
        if [ $? -gt 0 ]; then
                echo "存在しない項目名です"
                echo "最初からやり直してください"
                exit 1
        fi
}

#項目内容数だけ項目内容を入力（引数：データベース名,テーブル名,SQLFILE名）
Create_sql(){
	local i=0
	local e
	local colum_sql
	local data_sql
	for e in "${ARRAY3[@]}"
	do
		if [ $i -eq 0 ]
		then
			colum_sql="INSERT INTO $2(${ARRAY3[i]}"
			data_sql="VALUES('${ARRAY3[i+1]}'"
		else
			colum_sql="$colum_sql,${ARRAY3[i]}"
			data_sql="$data_sql,'${ARRAY3[i+1]}'"
		fi
		i=$(( $i + 2 ))
		#配列要素最大か
		if [ $i -eq ${#ARRAY3[@]} ]
		then
			colum_sql="$colum_sql)"
			data_sql="$data_sql);"
			break
		fi
	done
	{ echo "use $1;"
		echo "$colum_sql $data_sql"
	} >> $3
}


echo "SQLファイルを新規作成(INSERT)"
read -p "ファイル名を入力 : " SQLFILE </dev/tty
File $SQLFILE
Account
Connect
Show_DB
read -p "データベース名を入力：" Show_DB </dev/tty
Show_Table $Show_DB
read -p "テーブル名を入力 : " Show_Table </dev/tty
Show_TableInf $Show_DB $Show_Table
Insert_inf $Show_DB $Show_Table
Create_sql $Show_DB $Show_Table $SQLFILE
echo "----------------"
echo "ファイル名：$SQLFILE"
cat $SQLFILE
