function ts-domain
  tailscale status --json | jq -r '.CertDomains[0]'
end

function pwr-battery
  system76-power profile battery
end

function pwr-balanced
  system76-power profile balanced
end

function klog
  argparse 'n/namespace=' -- $argv
  if set -q _flag_namespace
    kail --ns=$_flag_namespace --output=raw --deploy=$args[1] | fblog
  else
    kail --output=raw --deploy=$args[1] | fblog
  end
end
