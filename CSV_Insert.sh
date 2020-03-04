#!/bin/bash

#ファイルが存在するか(引数：ファイル名,拡張子判断)
File(){
	local file=$1
	if [ "$2" == "csv" ]
	then
		if [ ! -f "$file.csv" ]
		then
			echo "ファイルが存在しません。"
			echo "最初からやり直してください。"
			exit 1
		else
			FILE="$FILE.csv"
		fi
	elif [ "$2" == "sql" ]
	then
		if [ ! -f "$file.sql" ]
		then
			FILE2="$FILE2.sql"
		else
			echo "上書きしていきます"
			FILE2="$FILE2.sql"
		fi
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
#配列の中身を縦に表示
Show_array(){
	local e
	unset ARRAY[0]	
	for e in "${ARRAY[@]}"
	do
		echo "*** ${e}"
	done
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
#CSVの列数を数える(引数：ファイル名)
Csv_colum(){
	local ret
	local array
	ret=`head -n 1 $1 | sed -e '1s/,/ /g'`
	array=($ret)
	COLUM=${#array[@]}
}
#テーブル項目を表示(引数:データベース名,テーブル名)
Table_inf(){
	local ret
	local file=".my.cnf"
	ret=`mysql --defaults-extra-file=./$file -u $USER -e "use $1;SHOW COLUMNS FROM $2"`
        if [ $? -gt 0 ]
       	then
                echo "存在しないテーブル名です"
                echo "最初からやり直してください"
                exit 1
        fi
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
	Show_array2
}
#配列の中身を横に表示
Show_array2(){	
	local e
	local data
	for e in "${ARRAY2[@]}"
	do
		data="$data ${e}"
	done
	echo "入力必須項目 $data"
}
#CSVの項目数とテーブルの項目数チェック
Check(){
	local check
	if [ $COLUM -lt ${#ARRAY2[@]} ]
	then
		echo "指定したCSVの項目がテーブルの入力必須項目数よりも少ないです。"
		read -p "続けますか[y/n]：" check
		if [ "$check" == "n" ]
		then
			exit 1
		fi
	fi
}
#SET配列をつくる(引数：データベース名、テーブル名）
Insert_colum(){
	local a=0
	while [ $a -lt $COLUM ]
	do
		read -p "$(( $a + 1 ))番目の項目名：" colum
		Check_colum $1 $2 $colum
		SET+=("$colum")
		let a++
	done
}

#sqlを作成（引数：データベース名,テーブル名）
Create_sql(){
	#行数
	local gyo=`wc -l $FILE | awk '{ print $1 }'`
	local j=1
	local i
	local set_sql
	local values_sql
	local sql
	local value
	while [ $j -le $gyo ]
	do
		i=0
		while [ $i -lt $COLUM ]
		do
			if [ $i -eq 0 ]
			then
				set_sql="INSERT INTO $2(${SET[i]}"
				value=`sed 's/ //g' $FILE | cut -d ',' -f $(( $i + 1 )) | sed -n -e "$j"p`
				values_sql="VALUES('$value'"
			else
				set_sql="$set_sql,${SET[i]}"
				value=`sed 's/ //g' $FILE | cut -d ',' -f $(( $i + 1 )) | sed -n -e "$j"p`
				values_sql="$values_sql,'$value'"
			fi
			let i++
		done
		set_sql="$set_sql)"
		values_sql="$values_sql);"
		#1行目か判定
		if [ $j -eq 1 ]
		then
			sql="$set_sql $values_sql"
		else
			sql="$sql\n$set_sql $values_sql"
		fi
		let j++
	done
	{ echo "use $1;"
		echo -e "$sql"
	} >> $FILE2
}


echo "csvファイルからINSERT文をつくります。"
read -p "csvファイルを指定(拡張子なし)：" FILE </dev/tty
File $FILE "csv"
Csv_colum $FILE
Account
Connect
Show_DB
read -p "データベース名を入力 : " Show_DB </dev/tty
Show_Table $Show_DB
read -p "テーブル名を入力 : " Show_Table </dev/tty
Table_inf $Show_DB $Show_Table
Check
echo "項目名を${COLUM}つ選んでください"
Insert_colum $Show_DB $Show_Table
read -p "SQLファイル名を入力(拡張子なし)：" FILE2 </dev/tty
File $FILE2 "sql"
Create_sql $Show_DB $Show_Table
echo "-----------"
echo "ファイル名：${FILE2}"
cat $FILE2
