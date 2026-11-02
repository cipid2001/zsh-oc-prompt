A simple oh-my-zsh plugin based on https://github.com/superbrothers/zsh-kubectl-prompt plugin 

Example: you have 10 OCP clusters. 7 production and 3 staging. In my case the "4" letter in cluster name made the difference : "p" = production and "s" = staging, in this way I differentiate on which cluster I am. 

.oc_clusters => create a file in $HOME/  and put the name of your cluster

.oc.zsh and zsh-oc-prompt.plugin.zsh => copy them to .oh-my-zsh/custom/plugin/ under zsh-oc-prompt directory 

To activate the plugin, add in .zshrc at plugins list ( zsh-oc-prompt ) and restart zsh shell. 

If you are not login to the cluster, no PROMPT will be displayed. If you connect to a cluster it will show in the right side the name of the cluster (in red if it's a production cluster or in orange if it's a staging cluster or if it's not in the list it will be show the name of the cluster in white) and then follow by the namespace name. 
