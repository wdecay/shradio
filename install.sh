DEST_DIR=/usr/local/share/shradio
mkdir -p $DEST_DIR
cp index.html radio.sh $DEST_DIR/
cp shradio /etc/init.d/
systemctl daemon-reload
