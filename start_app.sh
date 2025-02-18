#!/bin/bash


start_app(){
    app_name=$1
    replica_count=$(midclt call chart.release.get_instance "$app_name" | jq '.config.controller.replicas // .config.workload.main.replicas // .pod_status.desired')

    if [[ $replica_count == "0" ]]; then
        echo -e "${blue}$app_name${red} cannot be started${reset}"
        echo -e "${yellow}Replica count is 0${reset}"
        echo -e "${yellow}This could be due to:${reset}"
        echo -e "${yellow}1. The application does not accept a replica count (external services, cert-manager etc)${reset}"
        echo -e "${yellow}2. The application is set to 0 replicas in its configuration${reset}"
        echo -e "${yellow}If you beleive this to be a mistake, please submit a bug report on the github.${reset}"
        exit
    fi

    if [[ $replica_count == "null" ]]; then
        echo -e "${blue}$app_name${red} cannot be started${reset}"
        echo -e "${yellow}Replica count is null${reset}"
        echo -e "${yellow}Looks like you found an application HS cannot handle${reset}"
        echo -e "${yellow}Please submit a bug report on the github.${reset}"
        exit
    fi

    echo -e "Starting ${blue}$app_name${reset}..."


    # Check for cnpg pods and scale the application
    cnpg=$(k3s kubectl get pods -n ix-"$app_name" -o=name | grep -q -- '-cnpg-' && echo "true" || echo "false")

    if [[ $cnpg == "true" ]]; then
        k3s kubectl get deployments,statefulsets -n ix-"$app_name" | grep -vE -- "(NAME|^$|-cnpg-)" | awk '{print $1}' | sort -r | xargs -I{} k3s kubectl scale --replicas="$replica_count" -n ix-"$app_name" {} &>/dev/null
        #TODO: Add a check to ensure the pods are running
        echo -e "${yellow}Sent the command to start all pods in: $app_name${reset}"
        echo -e "${yellow}However, HeavyScript cannot monitor the new applications${reset}"
        echo -e "${yellow}with the new postgres backend to ensure it worked..${reset}"
    elif cli -c 'app chart_release scale release_name='\""$app_name"\"\ 'scale_options={"replica_count": '"$replica_count}" &> /dev/null; then
        echo -e "${blue}$app_name ${green}Started${reset}"
        echo -e "${green}Replica count set to ${blue}$replica_count${reset}"
    else
        echo -e "${red}Failed to start ${blue}$app_name${reset}"
    fi

}
