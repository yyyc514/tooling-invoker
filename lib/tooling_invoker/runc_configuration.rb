module ToolingInvoker
  class RuncConfiguration
    def initialize(working_directory, rootfs_source, invocation_args)
      @rootfs_source = rootfs_source
      @working_directory = File.expand_path(working_directory)
      @invocation_args = invocation_args

      @uid_id = `id -u`.chomp
      @gid_id = `id -g`.chomp
    end

    def to_json(*_args)
      config = <<-CONFIG
      {
        "ociVersion": "1.0.1-dev",
        "process": {
          "terminal": false,
          "user": {
            "uid": 0,
            "gid": 0
          },
          "env": [
            "GEM_HOME=/usr/local/bundle",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "TERM=xterm"
          ],
          "cwd": "#{working_directory}",
          "rlimits": [
            {
              "type": "RLIMIT_NOFILE",
              "hard": 1024,
              "soft": 1024
            },
            {
              "type": "RLIMIT_CPU",
              "hard": 70,
              "soft": 60
            },
            {
              "type": "RLIMIT_RTTIME",
              "hard": 70,
              "soft": 60
            }
          ],
          "noNewPrivileges": true
        },
        "root": {
          "path": "#{rootfs_source}",
          "readonly": true
        },
        "hostname": "exercism-runner",
        "mounts": [
          {
            "destination": "/mnt/exercism-iteration",
            "source": "./code",
            "options": [ "rbind", "rw" ]
          },
          {
            "destination": "/tmp",
            "source": "./tmp",
            "options": [ "rbind", "rw" ]
          },
          {
            "destination": "/proc",
            "type": "proc",
            "source": "proc"
          },
          {
            "destination": "/dev",
            "type": "tmpfs",
            "source": "tmpfs",
            "options": [
              "nosuid",
              "strictatime",
              "mode=755",
              "size=65536k"
            ]
          },
          {
            "destination": "/dev/pts",
            "type": "devpts",
            "source": "devpts",
            "options": [
              "nosuid",
              "noexec",
              "newinstance",
              "ptmxmode=0666",
              "mode=0620"
            ]
          },
          {
            "destination": "/dev/shm",
            "type": "tmpfs",
            "source": "shm",
            "options": [
              "nosuid",
              "noexec",
              "nodev",
              "mode=1777",
              "size=65536k"
            ]
          },
          {
            "destination": "/dev/mqueue",
            "type": "mqueue",
            "source": "mqueue",
            "options": [
              "nosuid",
              "noexec",
              "nodev"
            ]
          },
          {
            "destination": "/sys",
            "type": "none",
            "source": "/sys",
            "options": [
              "rbind",
              "nosuid",
              "noexec",
              "nodev",
              "ro"
            ]
          }
        ],
        "linux": {
          "uidMappings": [
            {
              "containerID": 0,
              "hostID": #{uid_id},
              "size": 1
            }
          ],
          "gidMappings": [
            {
              "containerID": 0,
              "hostID": #{gid_id},
              "size": 1
            }
          ],
          "namespaces": [
            {
              "type": "pid"
            },
            {
              "type": "ipc"
            },
            {
              "type": "uts"
            },
            {
              "type": "mount"
            },
            {
              "type": "user"
            }
          ],
          "maskedPaths": [
            "/proc/kcore",
            "/proc/latency_stats",
            "/proc/timer_list",
            "/proc/timer_stats",
            "/proc/sched_debug",
            "/sys/firmware",
            "/proc/scsi"
          ],
          "readonlyPaths": [
            "/proc/asound",
            "/proc/bus",
            "/proc/fs",
            "/proc/irq",
            "/proc/sys",
            "/proc/sysrq-trigger"
          ]
        }
      }
      CONFIG
      parsed = JSON.parse(config)
      parsed["process"]["args"] = invocation_args
      parsed.to_json
    end

    private
    attr_reader :rootfs_source, :uid_id, :gid_id, :invocation_args, :working_directory
  end
end
