setopt prompt_subst
autoload -U add-zsh-hook

# Setează binarul implicit la "oc"
zstyle -s ':zsh-oc-prompt:' binary binary || zstyle ':zsh-oc-prompt:' binary "oc"

# Variabile de cache în memorie
typeset -g _OC_CACHED_NOW=""
typeset -g _OC_AUTH_STATUS=""
typeset -g _OC_LAST_CHECK=0

add-zsh-hook precmd _zsh_oc_prompt_precmd

function _zsh_oc_prompt_precmd() {
    local kubeconfig config now updated_at binary modified_time_fmt
    local context ns server_url cluster_name cluster_color env_file fourth_char timeout_cmd
    local current_time=$EPOCHSECONDS

    zstyle -s ':zsh-oc-prompt:' binary binary
    if ! command -v "$binary" >/dev/null; then
        ZSH_OC_PROMPT=""
        return 1
    fi

    kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    [[ -f "$kubeconfig" ]] || { ZSH_OC_PROMPT=""; return 1; }

    # Detectăm sintaxa corectă pentru comanda stat (Linux GNU vs macOS/BSD)
    zstyle -s ':zsh-oc-prompt:' modified_time_fmt modified_time_fmt
    if [[ -z "$modified_time_fmt" ]]; then
        if stat --help >/dev/null 2>&1; then
            modified_time_fmt='-c%y' # GNU (Linux)
        else
            modified_time_fmt='-f%m' # BSD / macOS
        fi
        zstyle ':zsh-oc-prompt:' modified_time_fmt "$modified_time_fmt"
    fi

    # Calculăm timestamp-ul curent al fișierului kubeconfig
    while read -d ":" config; do
        [[ -n "$config" ]] && now="${now}${config}:$(stat -L $modified_time_fmt "$config" 2>/dev/null)"
    done <<< "${kubeconfig}:"

    # --- CACHE OPTIMIZAT (TTL 5 minute) ---
    if [[ "$_OC_CACHED_NOW" == "$now" && -n "$_OC_AUTH_STATUS" && $(( current_time - _OC_LAST_CHECK )) -lt 300 ]]; then
        if [[ "$_OC_AUTH_STATUS" == "false" ]]; then
            ZSH_OC_PROMPT=""
        fi
        return 0
    fi

    _OC_CACHED_NOW="$now"
    _OC_LAST_CHECK="$current_time"

    # --- VERIFICARE AUTENTIFICARE CU TIMEOUT DE 3 SECUNDE ---
    # Detectăm comanda de timeout (Linux coreutils `timeout` sau macOS `gtimeout`)
    if command -v timeout >/dev/null; then
        timeout_cmd="timeout 3"
    elif command -v gtimeout >/dev/null; then
        timeout_cmd="gtimeout 3"
    else
        timeout_cmd=""
    fi

    # Rulăm 'oc whoami' limitat la maxim 3 secunde
    if [[ -n "$timeout_cmd" ]]; then
        if ! eval "$timeout_cmd $binary whoami &>/dev/null"; then
            _OC_AUTH_STATUS="false"
            ZSH_OC_PROMPT=""
            return 0
        fi
    else
        # Fallback dacă nu există utilitarul timeout pe sistem
        if ! "$binary" whoami &>/dev/null; then
            _OC_AUTH_STATUS="false"
            ZSH_OC_PROMPT=""
            return 0
        fi
    fi

    _OC_AUTH_STATUS="true"

    # --- Extragere date cluster și namespace ---
    context="$("$binary" config current-context 2>/dev/null)"
    [[ -z "$context" ]] && { ZSH_OC_PROMPT=""; return 0; }

    ns="$("$binary" project -q 2>/dev/null)"
    if [[ -z "$ns" ]]; then
        ns="$("$binary" config view -o "jsonpath={.contexts[?(@.name==\"$context\")].context.namespace}" 2>/dev/null)"
        [[ -z "$ns" ]] && ns="default"
    fi

    server_url="$("$binary" config view --minify -o jsonpath='{.clusters[0].server}' 2>/dev/null)"

    if [[ -n "$server_url" ]]; then
        cluster_name=${server_url#https://}
        cluster_name=${cluster_name#http://}
        cluster_name=${cluster_name%%:*}
        cluster_name=${cluster_name#api.}
        cluster_name=${cluster_name%%.*}
    else
        cluster_name="$context"
        cluster_name=${cluster_name#*/}
        cluster_name=${cluster_name%%/*}
        cluster_name=${cluster_name#api-}
        cluster_name=${cluster_name#api.}
        cluster_name=${cluster_name%%-*}
        cluster_name=${cluster_name%%.*}
    fi

    # --- LOGICĂ DE CULOARE ---
    cluster_color="white"
    env_file="$HOME/.oc_clusters"
    if [[ -f "$env_file" ]] && grep -i -q -w "$cluster_name" "$env_file"; then
        if grep -i "PROD:" "$env_file" | grep -i -q -w "$cluster_name"; then
            cluster_color="red"
        elif grep -i "STAGING:" "$env_file" | grep -i -q -w "$cluster_name"; then
            cluster_color="yellow"
        fi
    else
        fourth_char="${cluster_name:3:1}"
        if [[ "$fourth_char" == "p" || "$cluster_name" == "crc" ]]; then
            cluster_color="red"
        elif [[ "$fourth_char" == "s" ]]; then
            cluster_color="yellow"
        fi
    fi

    # Formatare finală: Nume cluster colorat | Namespace ALB
    ZSH_OC_PROMPT="%F{red}⎈%f %F{${cluster_color}}${cluster_name}%f:%F{white}${ns}%f"
}

# Afișarea în prompt (partea dreaptă - RPS1)
RPS1='${ZSH_OC_PROMPT} '"$RPS1"
