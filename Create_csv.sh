#!/bin/bash
#整数判定
Int(){
	local ret
	expr $1 + 1 > /dev/null 2>&1
	ret=$?
	#整数判定
	if [ "$ret" -lt 2 ]
	then
		if [ $1 -le 0 ]
		then
			echo "1以上の数値を入力してください"
			exit 1
		fi
	else
		echo "数値を入力してください"
		exit 1
	fi
}
#ファイルに書き込み（引数：行、列）
CSV(){
	local cj ci colum
	cj=1
	ci=1
	##指定した行の数だけループ
	while [ $cj -le $1 ] 
	do
		colum=""
		ci=1
		##指定した列の数だけループ
		while [ $ci -le $2 ]
		do
			read -p "${cj}行${ci}列目を入力 : " rev
			if [ $ci -eq 1 ]
			then
				colum="$rev"
			else
				colum="$colum, $rev"
			fi
			ci=$(( ci + 1 ))
		done
		echo "${colum}を書き込み"
		echo $colum >>$FILE
		cj=$(( cj + 1 ))
	done
}
#ファイル存在判定
Create_File(){
	local file_name
	read -p "ファイル名を指定(拡張子なし) : " file_Name
	if [ -e "$file_Name.csv" ]
	then
		echo "既に存在するファイル名です。"
		exit 0
	else
		FILE=$file_Name.csv
	fi
}
echo "CSVファイルを新規作成します"
read -p "行数を指定 : " gyo
Int $gyo
read -p "列数を指定 : " retu
Int $retu
Create_File
echo "${gyo}行${retu}列の${FILE}を作成します"
CSV $gyo $retu
echo "----------------------"
echo "ファイル名：$FILE"
cat $FILE
