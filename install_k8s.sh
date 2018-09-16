#/usr/bin/env bash
set -e
current_path=$(
	cd $(dirname $0)
	pwd
)

function cfg_host() {
	echo "Start to ${FUNCNAME[0]} ..."
	yum install -y vim
	host_ip=$(ip -o -4 a s eth0 | awk '{print $4}' | cut -d'/' -f1)
	echo "${host_ip} k8s-master" >>/etc/hosts

	setenforce 0 | true
	echo 'SELINUX=disabled' >>/etc/sysconfig/selinux
	systemctl stop firewalld.service    #停止firewall
	systemctl disable firewalld.service #禁止firewall开机启动
	firewall-cmd --state | true         #查看防火墙状态

	modprobe br_netfilter
	echo '1' >/proc/sys/net/bridge/bridge-nf-call-iptables

	echo <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
	sysctl -p /etc/sysctl.d/k8s.conf

	swapoff -a
	sed -i 's/^.*swap.*/#&/g' /etc/fstab
	echo "End to ${FUNCNAME[0]}"
}

function install_docker() {
	echo "Start to ${FUNCNAME[0]} ..."
	yum install -y yum-utils device-mapper-persistent-data lvm2
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	yum list docker-ce.x86_64 --showduplicates | sort -r
	yum makecache fast
	yum install -y --setopt=obsoletes=0 docker-ce-17.03.2.ce-1.el7.centos docker-ce-selinux-17.03.2.ce-1.el7.centos
	echo "End to ${FUNCNAME[0]}"
}
function install_kubeadm() {
	echo "Start to ${FUNCNAME[0]} ..."
	cat <<EOF >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
	yum install -y kubelet kubeadm kubectl
	systemctl start docker && systemctl enable docker
	systemctl start kubelet && systemctl enable kubelet
	docker_driver=$(docker info | grep -i cgroup | awk '{print $3}')
	if [ -f /etc/systemd/system/kubelet.service.d/10-kubeadm.conf ]; then
		kubelet_driver=$(cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf | grep cgroup)
		if [[ ! -z ${kubelet_driver} ]]; then
			sed -i 's/cgroup-driver=systemd/cgroup-driver=cgroupfs/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
		fi
	fi
	echo "End to ${FUNCNAME[0]}"
}

function install_master() {
	echo "Start to ${FUNCNAME[0]} ..."
	kubeadm init --apiserver-advertise-address=${host_ip} --pod-network-cidr=10.244.0.0/16 >/tmp/install_k8s.log 2>&1

	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config

	echo "alias kd=\"kubectl\"" >>/etc/profile
	echo "alias ks=\"kubectl -n kube-system\"" >>/etc/profile
	kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	echo "End to ${FUNCNAME[0]}"
}
function install_istio() {
	echo "Start to ${FUNCNAME[0]} ..."
	wget https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-rc.2-linux-amd64.tar.gz --no-check-certificate
	tar -zxvf helm-v2.11.0-rc.2-linux-amd64.tar.gz
	cp linux-amd64/helm /usr/local/bin/
	cp linux-amd64/tiller /usr/local/bin/

	curl -L https://git.io/getLatestIstio | sh -
	cd istio-1.0.2/
	# helm template install/kubernetes/helm/istio --name istio --namespace istio-system >$HOME/istio.yaml
	# kubectl create namespace istio-system
	# kubectl apply -f $HOME/istio.yaml
	echo "End to ${FUNCNAME[0]}"
}

function main() {
	pushd ${current_path}
	cfg_host
	install_docker
	install_kubeadm
	if [[ $1 == "master" ]]; then
		echo "---------------------------------"
		echo "This node is for master"
		install_master
		echo "---------------------------------"
	fi
	popd
}

main "$@"
