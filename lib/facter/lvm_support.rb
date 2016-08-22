# lvm_support: true/nil
#   Whether there is LVM support (based on the presence of the "vgs" command)
Facter.add('lvm_support') do
  confine :kernel => "Linux"

  setcode do
    vgdisplay = Facter::Util::Resolution.which('vgs')
    vgdisplay.nil? ? nil : true
  end
end

# lvm_vgs: [0-9]+
#   Number of VGs
vg_list = []
Facter.add('lvm_vgs') do
#  confine :kernel => "Linux"
  confine :lvm_support => true
#  setcode do
#  vgs = Facter::Core::Execution.execute('vgs -o name --noheadings 2>/dev/null', options = {:timeout => 30})
  vgs = Facter::Util::Resolution.exec('vgs -o name --noheadings 2>/dev/null')
  if vgs.nil?
    setcode { 0 }
  else
    vg_list = vgs.split
    setcode { vg_list.length }
  end
end

# lvm_vg_[0-9]+
#   VG name by index
vg_list.each_with_index do |vg, i|
  Facter.add("lvm_vg_#{i}") { setcode { vg } }
end

# lvm_pvs: [0-9]+
#   Number of PVs
$pv_list = []
Facter.add('lvm_pvs') do
  confine :lvm_support => true

  setcode do
    pvs = Facter::Core::Execution.execute('pvs -o name --noheadings 2>/dev/null', options = {:timeout => 30})
    if pvs.nil?
      0
    else
      $pv_list = pvs.split
      $pv_list.length
    end
  end
end

# lvm_pv_[0-9]+
#   PV name by index
$pv_list.each_with_index do |pv, i|
  Facter.add("lvm_pv_#{i}") { setcode { pv } }
end
