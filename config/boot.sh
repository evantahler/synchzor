#!/bin/bash

# Update btsync config with ENV
sed -i -e "s/XX_SECRET_XX/$BTSYNC_SHARE_SECRET/g" /btsync/btsync.conf
sed -i -e "s/XX_DIR_XX/\/s3bucket\/synchzor\/$SYNCHZOR_USER\/$SYNCHZOR_FOLDER/g" /btsync/btsync.conf

# mount fuse
/usr/bin/s3fs $S3_BUCKET /s3bucket -o parallel_count=50 -o use_sse -o nonempty

# let it connect...
sleep 5

# turn on btsync
/usr/bin/btsync --config /btsync/btsync.conf --nodaemon