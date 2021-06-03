#!/bin/bash

printf "\nGetting Encoder Tools...\n"
wget -q "https://gdrive.phantomzone.workers.dev/0:/ffmpeg_SlimStaticBuild/ffmpeg"
wget -q "https://gdrive.phantomzone.workers.dev/0:/NeroAACCodec/linux/neroAacEnc"
chmod a+x ffmpeg neroAacEnc
sudo mv ffmpeg neroAacEnc /usr/local/bin/

printf "\nSetting Up Rclone with Config...\n"
curl -sL https://rclone.org/install.sh | sudo bash &>/dev/null
mkdir -p ~/.config/rclone
curl -sL "${RCLONE_CONFIG_URL}" > ~/.config/rclone/rclone.conf

# Get File from Season 01
#export EpNum="01"    # Feed it from External Script/Command {01..26}
aria2c -c -s16 -x8 -m20 --console-log-level=warn --summary-interval=30 --check-certificate=false \
  "https://gdrive.phantomzone.workers.dev/0:/TorrentXbot/MLB.S01.1080p.NF.WEBRip.DDP5.1.x264-TrollHD/Miraculous%20-%20Tales%20of%20Ladybug%20&%20Cat%20Noir%20S01E${EpNum}%201080p%20Netflix%20WEB-DL%20DD+%205.1%20x264-TrollHD.mkv"
ls -lAog

# Remove Unwanted Characters From Filename & Modify For Conversion 
export INFILE="Miraculous - Tales of Ladybug & Cat Noir S01E${EpNum} 1080p Netflix WEB-DL DD+ 5.1 x264-TrollHD.mkv"
export ConvertedName="$(echo "$INFILE" | sed 's/ - /-/g;s/ /./g;s/1080p.*/1080p/g')"
mv "$INFILE" $ConvertedName.mkv
ls -lAog

sleep 2s
set -xv
# Audio Pan
FL="0.818*FC + 0.818*FL + 0.707*BL + 0.222*BR + 0.4*LFE"
FR="0.818*FC + 0.818*FR + 0.707*BR + 0.222*BL + 0.6*LFE"
# Convert Audio With NeroAacEnc for VBR 96k Quality
ffmpeg -hide_banner -y -i "$ConvertedName.mkv" -map_metadata -1 -map_chapters 0 \
  -map 0:1 -c:a pcm_f32le -ar 44100 \
  -af "volume=2.0,pan=stereo|FL < $FL|FR < $FR" \
  -f wav /tmp/aud_enhanced_f32le.wav
file /tmp/aud_enhanced_f32le.wav
neroAacEnc -he -q 0.33 -if /tmp/aud_enhanced_f32le.wav -of aud_enhanced_nero-lo.mp4
sleep 2s
# Convert Video + Join Previously Converted Audio + Original English Subtitle 
ffmpeg -hide_banner -y -i "$ConvertedName.mkv" -i aud_enhanced_nero-lo.mp4 \
  -map_metadata -1 -map_chapters 0 -map 0:v:0 -map 1:a:0 \
  -vf "scale=iw/3:ih/3" -c:v libx265 -x265-params me=4:subme=3:rd=3 \
  -preset slower -tune animation -crf 21 -movflags faststart \
  -metadata:s:v title="Miraculous - Tales of Ladybug & Cat Noir | S01E${EpNum}" \
  -c:a copy -movflags disable_chpl \
  -metadata:s:1 language=english -metadata:s:1 title="English Audio" \
  -map 0:3 -c:s copy \
  -metadata:s:2 language=english -metadata:s:2 title="English Caption" \
  -reserve_index_space 20k \
  "${ConvertedName/1080p/360p.x265}.mkv"
sleep 2s
set +xv

# Upload File
rclone copy "${ConvertedName/1080p/360p.x265}.mkv" td:/MLB_Converted/S01/ -P
curl --upload-file "${ConvertedName/1080p/360p.x265}.mkv" https://transfer.sh && echo
