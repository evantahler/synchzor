## Docker notes

```
docker run -it --rm \
  # -p 8080:8080 \
  # -p 55555:55555 \
  --name='synchzor_docker' \
  --env AWSACCESSKEYID=XXX \
  --env AWSSECRETACCESSKEY=XXX \
  --env S3_BUCKET=XXX \
  --env SYNCHZOR_USER=evantahler \
  --env SYNCHZOR_FOLDER=art \
  --env BTSYNC_SHARE_SECRET='XXX' \
  --privileged \
  'synchzor/synchzor'
```