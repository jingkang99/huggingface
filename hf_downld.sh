#!/usr/bin/bash

# 5/22/26 download multiple HF big model files
# https://huggingface.co/unsloth/Mistral-Medium-3.5-128B-GGUF/tree/main/UD-Q8_K_XL
RED='\033[0;31m'
YLW='\033[0;33m'
BLU='\033[0;34m'
BLB='\033[1;34m'
GRN='\033[0;32m'
BCY='\033[1;36m'
CYA='\033[0;36m'
NCL='\033[0m'


function show_help() {

echo -en "\n  ${BLB}Usage${NCL}: "
    cat << EOF
$(basename "$0") [-h] [-s|-m] MODEL_ROOT MODEL_QUANT

  command to download hf model's multiple or single gguf file

  Options:
    -h          show this help text and exit
    -c          sha256sum checking gguf files	
    -m          download multiple gguf files
    -s          download single gguf file
    MODEL_ROOT	hf model repository root
    MODEL_QUANT quantized model, default: UD-Q8_K_XL

  Example:
    $(basename "$0") -m unsloth/Mistral-Medium-3.5-128B-GGUF

EOF
}

# usage:
# hf_mf_download unsloth/Mistral-Medium-3.5-128B-GGUF
function hf_mf_download(){
	CARD="$1"
	QUNT="${2:-UD-Q8_K_XL}"

	BASE=https://huggingface.co/${CARD}
	ROOT=${BASE}"/tree/main/"${QUNT}

	[[ ! -e _1 ]] && wget -q ${ROOT} -O _1
	mapfile -t files < <(grep -oP ${CARD}'/blob/[^"]+' _1 | xargs -I % echo % | awk  -F '/' '{print $6}')

	TOTL=${#files[@]}
	printf "%s\n" "${files[@]}" > _url
	printf "  %s files found for %s %s\n" $TOTL $CARD $QUNT

	for (( i=0; i < $TOTL; i++ )); do
		TURL=${BASE}/resolve/main/${QUNT}/${files[$i]}
		FILE="${TURL##*/}"

		SECONDS=0
		PNTTIME=0
		# if .aria2 exists, download not completed
		if   [ ! -e ${FILE} ]; then
			echo -e "  ${CYA}download $FILE${NCL}"
			PNTTIME=1
		elif [ -e ${FILE}'.aria2' ] && [ -e ${FILE} ]; then
			echo -e "  ${YLW}continue $FILE${NCL}"
			PNTTIME=1
		else
			echo -e "  ${GRN}complete $FILE${NCL}"
			continue
		fi

		aria2c --console-log-level=warn --continue=true --show-console-readout=false \
		  --summary-interval=300 -x 16 -s 16 -o $FILE $TURL
		if [ $? -ne 0 ]; then
			sleep 30
			echo aria2c --console-log-level=warn --continue=true --show-console-readout=false \
			--summary-interval=300 -x 16 -s 16 -o $FILE $TURL
			echo "  ${RED}  error${NCL}"
			return
		fi

		ELASPED="$((SECONDS/3600))h $(((SECONDS%3600)/60))m $((SECONDS%60))s"
		[[ $PNTTIME -eq 1 ]] &&  echo -e "  task completd: $ELASPED for" $(du -sh $FILE)"\n"
	done

	hf_sha256ck $1 $2
}

function hf_sf_download(){
	CARD="$1"
	QUNT="${2:-UD-Q8_K_XL}"

	BASE=https://huggingface.co/${CARD}
	ROOT=${BASE}"/tree/main/"${QUNT}

	declare -a files
	[[ ! -e _1 ]] && wget -q ${ROOT} -O _1
	if [ $? -ne 0 ]; then	#single file
		ROOT=${BASE}"/tree/main"
		echo -e "  download single file $QUNT $ROOT"
		wget -q ${ROOT} -O _1

		CAR1=$(echo $CARD | awk -F'/' '{print $2}')
		FILN=${CAR1/GGUF/$QUNT}".gguf"
		URLF=$BASE"/resolve/main/"$FILN

		SECONDS=0
		PNTTIME=0
		if   [ ! -e ${FILN} ]; then
			echo -e "  ${CYA}download $FILN${NCL}"
			PNTTIME=1
		elif [ -e ${FILN}'.aria2' ] && [ -e ${FILN} ]; then
			echo -e "  ${YLW}continue $FILN${NCL}"
			PNTTIME=1
		else
			echo -e "  ${GRN}complete $FILN${NCL}"
			return
		fi

		SECONDS=0
		aria2c --console-log-level=warn --continue=true --show-console-readout=false \
		  --summary-interval=300 -x 16 -s 16 -o $FILN $URLF

		ELASPED="$((SECONDS/3600))h $(((SECONDS%3600)/60))m $((SECONDS%60))s"
		[[ $PNTTIME -eq 1 ]] &&  echo -e "  task completd: $ELASPED for" $(du -sh $FILN)"\n"
		return
	else
		mapfile -t files < <(grep -oP ${CARD}'/blob/[^"]+' _1 | xargs -I % echo % | awk  -F '/' '{print $6}')
	fi
}

function hf_sha256ck(){
	CARD="$1"
	QUNT="${2:-UD-Q8_K_XL}"

	BASE=https://huggingface.co/${CARD}
	ROOT=${BASE}"/tree/main/"${QUNT}

	rm -rf _1
	wget -q ${ROOT} -O _1

	mapfile -t files < <(grep -oP ${CARD}'/blob/[^"]+' _1 | xargs -I % echo % | awk  -F '/' '{print $6}')

	TOTL=${#files[@]}

	rm -rf _sha256.sum
	for (( i=0; i < $TOTL; i++ )); do
		DESC=${BASE}/blob/main/${QUNT}/${files[$i]}
		FILE="${DESC##*/}"
		wget -q $DESC -O _2
		regex="SHA256:.+>([a-zA-Z0-9]{64})<"
		match=$(grep -oP "$regex" _2)
		if [[ $match =~ $regex ]]; then
			echo "${BASH_REMATCH[1]}  ${FILE}" | tee -a _sha256.sum
		fi
	done
}

#  -----

if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

while getopts ":chv:s:m:" opt; do
    case "${opt}" in
        h)
            show_help
            exit 0
            ;;
        c)
            [ ! -e _sha256.sum ] && exit 1
			start_time=$(date +%s)
            sha256sum -c _sha256.sum | tee _sha256.chk
            end_time=$(date +%s)
            echo "  sha256sum chk:" $(($end_time-$start_time))
            exit 0
            ;;
        s)
            hf_sf_download $2 $3
            ;;
        m)
            start_time=$(date +%s)
            hf_mf_download $2 $3
            end_time=$(date +%s)
            echo "  download time:" $(($end_time-$start_time))
            ;;
        \?)
            echo -e "  ${RED}Error${NCL}: invalid option -${OPTARG}" >&2
            show_help >&2
            exit 1
            ;;
        :)
            echo -e "  ${RED}Error${NCL}: option -${OPTARG} requires argument" >&2
            show_help >&2
            exit 1
            ;;
    esac
done
