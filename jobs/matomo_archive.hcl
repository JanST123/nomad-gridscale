variable "token_auth" {
  type = string
  description = "Token for running the cron, can be created in the matomo Security section"
}

variable "matomo_url" {
  type = string
  description = "External URL of matomo"
}


job "matomo_archive" {
 datacenters = ["dc1"]
 type = "batch" 

  periodic {
    cron             = "0 4 * * * *"
    prohibit_overlap = true
  }

  group "matomo" {
    count = 1

    task "matomo_archive_cron" {
      driver = "raw_exec"
 
      config {
        command = "curl"
        args    = ["${var.matomo_url}/misc/cron/archive.php?token_auth=${var.token_auth}"]
      }
    }
 }
}