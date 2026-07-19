{
  fileSystems. "/data" = {
    device = "/dev/sdb";
    fsType = "ext4";
    options = ["data=journal"];
  };
}
