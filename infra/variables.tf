variable img_display_name {
  type = string
  default = "almalinux-9.4-20240805"
}

variable namespace {
  type = string
  default = "ucabojm-comp0235-ns"
}

variable network_name {
  type = string
  default = "ucabojm-comp0235-ns/ds4eng"
}

variable username {
  type = string
  default = "ucabojm"
}

variable keyname {
  type = string
  default = "ucabojm-cnc"
}

variable worker_count {
  type    = number
  default = 4
}
