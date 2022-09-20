data "external" "git_sha" {
  program = ["bash", "../../scripts/get_sha.sh"]
}
