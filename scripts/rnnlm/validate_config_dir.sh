#!/usr/bin/env bash

# This script validates the inputs for RNNLM training.


if [ $# != 2 ]; then
  echo "Usage: $0 <text-dir> <rnnlm-config-dir>"
  echo "Validates <text-dir> and <rnnlm-config-dir>."
  echo "<text-dir> should be as validated by validate_data_dir.py."
  echo "<rnnlm-config-dir> contains various smallish user-provided"
  echo "files needed for RNNLM training:"
  echo "  words.txt  (vocabulary file with mapping to integers)"
  echo "  features.txt  [optional] File as generated by choose_features.py,"
  echo "              that determines the feature represenration."
  echo "              If not present, no feature representation will be "
  echo "              used, and each word's embedding is trained separately."
  echo "  data_weights.txt  File containing data multiplicities and"
  echo "     weighting factors for all data sources in <text-dir>,"
  echo "     except 'dev'.  e.g. with lines like"
  echo "       switchboard  1  0.5"
  echo "     Weights do not have to sum to one and can be greater"
  echo "     than one."
  echo "  oov.txt   Must either be a empty file, or contain the"
  echo "     written representation of the unknown word, usually"
  echo "     <unk> (only relevant if <text-dir> contains words not"
  echo "     present in words.txt)."
  echo "  xconfig   File containing xconfig representation of the"
  echo "     RNNLM to be created, as could be provided to"
  echo "     xconfig_to_configs.py"
  exit 1;
fi


text_dir=$1
config_dir=$2

set -e


for f in words.txt features.txt data_weights.txt oov.txt xconfig; do
  if [ ! -f $config_dir/$f ]; then
    echo "$0: file $config_dir/$f is not present."
    exit 1
  fi
done

rnnlm/validate_text_dir.py --spot-check=true $text_dir

rnnlm/validate_features.py $config_dir/features.txt

# basic check of words.txt
if ! echo 0 | utils/int2sym.pl $config_dir/words.txt >/dev/null; then
  echo "$0: detected a problem in $config_dir/words.txt"
  exit 1
fi


rnnlm/ensure_counts_present.sh $text_dir


# rnnlm/get_unigram_probs.py validates the data-weights file, so we're
# relying on that check rather than writing a special one.
if ! rnnlm/get_unigram_probs.py --vocab-file=$config_dir/words.txt \
                           --data-weights-file=$config_dir/data_weights.txt \
                           $text_dir >/dev/null; then
  echo "$0: detected problem, most likely with data-weights file $config_dir/data_weights.txt"
  echo " ... see errors above."
fi

# for words.txt: check number of fields per line is 2 and that the
# second is an integer; check that bos, eos and brk are in the
# expected positions.

if [ -s $config_dir/oov.txt ]; then
  # if oov.txt is nonempty...
  if ! awk '{if (NF!=1){ exit (1) }} END{if(NR != 1) exit(1)}' <$config_dir/oov.txt; then
    echo "$0: $config_dir/oov.txt does not look right."
    exit 1
  fi
  if ! utils/sym2int.pl $config_dir/words.txt <$config_dir/oov.txt >/dev/null; then
    echo "$0: the word in $config_dir/oov.txt does not exist in $config_dir/words.txt: '$(cat $config_dir/oov.txt)'"
    exit 1
  fi
fi


if grep '^\s*fixed-affine-layer' $config_dir/xconfig; then
  echo "$0: $config_dir/xconfig cannot contain a layer of type fixed-affine-layer."
  exit 1
fi


echo "$0: validated config dir $config_dir"
exit 0;
