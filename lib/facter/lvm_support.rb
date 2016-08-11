# lvm_support: true/nil
#   Whether there is LVM support (based on the presence of the "vgs" command)
Facter.add('lvm_support') do
  confine :kernel => "Linux"

  setcode do
    Facter::Core::Execution.which('vgs') != nil
  end
end

# lvm_vgs: [0-9]+
#   Number of VGs
vg_list = []
Facter.add('lvm_vg_list') do
#  confine :lvm_support => true
  confine :kernel => "Linux"
  setcode do
    vglist = Facter::Core::Execution.execute('vgs -o name --noheadings 2>/dev/null', options = {:timeout => 30})
    if vglist.nil?
      0
    else
      vg_list = vglist.split('\n').map!(&:strip)
      vg_list
    end
  end
end


#vg_list = []
#vgs = Facter.value (:lvm_vg_list)
#if vgs.nil?
#  0
#else
#  vg_list = vgs.split
#  vg_list = vgs.split("\n").select{|l| l =~ /^\s+\// }.collect(&:strip).sort.join(',')
#end

Facter.add('lvm_vgs') do
  confine :kernel => :Linux
  vgs = Facter.value (:lvm_vg_list)
  setcode do
    if vgs.nil?
      0
    else
      vg_list.length
    end
  end
end

# lvm_vg_[0-9]+
#   VG name by index
vg_list.each_with_index do |vg, i|
  Facter.add("lvm_vg_#{i}") { setcode { vg } }
  Facter.add("lvm_vg_#{vg}_pvs") do
    confine :kernel => "Linux"
    setcode do
      pvs = Facter::Core::Execution.execute("vgs -o pv_name #{vg} 2>/dev/null", options = {:timeout => 30})
      res = nil
      unless pvs.nil?
        res = pvs.split("\n").select{|l| l =~ /^\s+\// }.collect(&:strip).sort.join(',')
      end
      res
    end
  end
end

# lvm_pvs: [0-9]+
#   Number of PVs
Facter.add('lvm_pv_list') do
  confine :kernel => :Linux
  setcode do
    pvlist = Facter::Core::Execution.execute('pvs -o name --noheadings 2>/dev/null', options = {:timeout => 30})
    if pvlist.nil?
      0
    else
      pvlist
    end
  end
end

pv_list = []
pvs = Facter.value (:lvm_pv_list)
if pvs.nil?
  0
else
  pv_list = pvs.split
end

Facter.add('lvm_pvs') do
  confine :kernel => :Linux
  setcode do
    if pvs.nil?
      0
    else
      pv_list.length
    end
  end
end

# lvm_pv_[0-9]+
#   PV name by index
pv_list.each_with_index do |pv, i|
  Facter.add("lvm_pv_#{i}") { setcode { pv } }
end
