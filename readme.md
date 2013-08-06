# SYNCHZOR
*file sync(h) and sharing for nerds*

It's like drop-box from the command line.   Sort-of.

## Commands

### `synchzor init`
Creates the `.synchzor` file in the directory.  This contains the host, bucket, path, and credentials for this directory.  

### `synchzor sync`
The main command.  Push and Pull files from the server

### `synchzor wipe`
Removes all trace of this folder's contents from the server

## .synchzor files
Each directory you sync has a `.synchzor` file created in the root.  This file has JSON which looks like the following:

```json
{
  "host":              "https://s3.aws.com",
  "access-key":        "abc123",
  "access-key-secret": "abc123",
  "bucket":            "my-backups",
  "remote-directory"   "photos"
}
```

You can change the `remote-directory` to link to something else if you want to join a folder by a different name.

## Automatic / Daemon
coming soon.  Use cron for now :p