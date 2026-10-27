include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "unit" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_units/edge.hcl"
}
