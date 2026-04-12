#!/usr/bin/env bash

# auto-detect source directory (./code or ./src)
if [ -d "./code" ]; then
  APP_SRC_DIR="code"
elif [ -d "./src" ]; then
  APP_SRC_DIR="src"
else
  APP_SRC_DIR="src"
fi

# add envfile to shell
# Use ENV_FILE from GitHub Actions if available, else fallback to $APP_SRC_DIR/.env
# dotenv=${ENV_FILE:-./${APP_SRC_DIR}/.env}
dotenv=./${APP_SRC_DIR}/.env
if [ ! -f "$dotenv" ]; then
  echo "Environment file not found at $dotenv"
  exit 1
fi
source "$dotenv"

# colours
RED=$'\033[31m'
RED_BOLD=$'\033[1;31m'
BLUE=$'\033[34m'
BLUE_BOLD=$'\033[1;34m'
GREEN=$'\033[32m'
GREEN_BOLD=$'\033[1;32m'
YELLOW=$'\033[33m'
YELLOW_BOLD=$'\033[1;33m'
RESET=$'\033[0m'


function dotenvfile() { 
  # Define the output file
  OUTPUT_FILE="./${APP_SRC_DIR}/.env"
  # List of variables to exclude (case-sensitive)
  EXCLUDE_VARS=(
    "PATH"
    "HOME"
    "USER"
    "SHELL"
    "PWD"
    "LANG"
    "SHLVL"
    "_"
    "OLDPWD"
    "TERM"
    "SHELLOPTS"
    "BASHOPTS"
    "PS1"
    "HOSTNAME"
    "HOSTTYPE"
    "OSTYPE"
    "MACHTYPE"
    "LOGNAME"
    "UID"
    "EUID"
    "GROUPS"
    "LS_COLORS"
    "LESSCLOSE"
    "LESSOPEN"
    "XDG_"
    "SSH_"
    "GIT_"
    "NVM_BIN"
    "NVM_INC"
    "NVM_DIR"
    "COLORTERM"
    "LSCOLORS"
    "LESS"
    "NAME"
    "ZSH"
    "ZDOTDIR"
    "DISPLAY"
    "NVM_CD_FLAGS"
    "PAGER"
  )
  # Function to check if a variable should be excluded
  should_exclude() {
    local var_name="$1"
    for exclude in "${EXCLUDE_VARS[@]}"; do
      if [[ "$var_name" == "$exclude"* ]]; then
        return 0
      fi
    done
    return 1
  }

  # Clear existing .env file if it exists
  > "$OUTPUT_FILE"

  # Process each environment variable
  while IFS= read -r line; do
    # Split into variable name and value
    var_name="${line%%=*}"
    var_value="${line#*=}"
    
    # Skip if variable should be excluded
    if should_exclude "$var_name"; then
      continue
    fi
    
    # Escape special characters in the value (especially quotes and newlines)
    var_value_escaped=$(printf '%q' "$var_value")
    
    # Write to .env file
    echo "$var_name=$var_value_escaped" >> "$OUTPUT_FILE"
  done < <(env)

  echo "Created $OUTPUT_FILE with environment variables"
}

#1 create nginx config
function nginx_config {
  export DL_APP_NAME DL_APP_NGX_DOCROOT DL_APP_NGX_SERVER_NAME DL_APP_NGX_INDEX
  # Generate config 
  envsubst '${DL_APP_NAME},${DL_APP_NGX_DOCROOT},${DL_APP_NGX_SERVER_NAME},${DL_APP_NGX_INDEX}' < ./ops/nginx/app.template > ./ops/nginx/app.conf
}

#2 function to check which git branch
function git_branch {
  # Get the current Git branch
  branch=$(git rev-parse --abbrev-ref HEAD)

  # Check if branch is release/dev or release/prod
  if [[ $branch != "release/ec2-dev" ]] && [[ $branch != "release/ec2-prod" ]] && [[ $branch != "release/k8s-dev" ]] && [[ $branch != "release/dev" ]] && [[ $branch != "release/dev-v2" ]] && [[ $branch != "release/prev" ]] && [[ $branch != "release/prev-v2" ]] && [[ $branch != "release/prod" ]] && [[ $branch != "release/prod-v2" ]] && [[ $branch != "release/k8s-prod" ]]; then
    # Prompt the user to select a branch
    printf "Current branch is ${RED}$branch.${RESET} You can only deploy on ${GREEN}release/ec2-dev${RESET}, ${GREEN}release/ec2-prod${RESET}, ${GREEN}release/k8s-dev${RESET}, ${GREEN}release/dev${RESET}, ${GREEN}release/k8s-dev${RESET} or ${GREEN}release/k8s-prod${RESET}\n"
    printf "Please select branch:"
    printf "1) ${YELLOW}release/ec2-dev${RESET}\n"
    printf "2) ${YELLOW}release/ec2-prod${RESET}\n"
    printf "3) ${YELLOW}release/k8s-dev${RESET}\n"
    printf "4) ${YELLOW}release/dev${RESET}\n"
    printf "5) ${YELLOW}release/dev-v2${RESET}\n"
    printf "6) ${YELLOW}release/prev${RESET}\n"
    printf "7) ${YELLOW}release/prev-v2${RESET}\n"
    printf "8) ${YELLOW}release/k8s-prod${RESET}\n"
    printf "9) ${YELLOW}release/prod${RESET}\n"
    printf "10) ${YELLOW}release/prod-v2${RESET}\n"
    read -p "Enter choice: " choice

    # Switch based on choice
    case $choice in
      1)
        printf "Switching to ${GREEN}release/ec2-dev${RESET} branch"
        git switch release/ec2-dev
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/ec2-dev${RESET} branch\n"
          exit 1
        fi
        ;;
      2)
        echo "Switching to ${GREEN}release/ec2-prod${RESET} branch"
        git switch release/ec2-prod
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/ec2-prod${RESET} branch\n"
          exit 1
        fi
        ;;
      3)
        echo "Switching to ${GREEN}release/k8s-dev${RESET} branch"
        git switch release/k8s-dev
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/k8s-dev${RESET} branch\n"
          exit 1
        fi
        ;;
      4)
        echo "Switching to ${GREEN}release/dev${RESET} branch"
        git switch release/dev
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/dev${RESET} branch\n"
          exit 1
        fi
        ;;
      5)
        echo "Switching to ${GREEN}release/dev-v2${RESET} branch"
        git switch release/dev-v2
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/dev-v2${RESET} branch\n"
          exit 1
        fi
        ;;
      6)
        echo "Switching to ${GREEN}release/prev${RESET} branch"
        git switch release/prev
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/prev${RESET} branch\n"
          exit 1
        fi
        ;;
      7)
        echo "Switching to ${GREEN}release/prev-v2${RESET} branch"
        git switch release/prev-v2
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/prev-v2${RESET} branch\n"
          exit 1
        fi
        ;;
      8)
        echo "Switching to ${GREEN}release/k8s-prod${RESET} branch"
        git switch release/k8s-prod
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/k8s-prod${RESET} branch\n"
          exit 1
        fi
        ;;
      9)
        echo "Switching to ${GREEN}release/prod${RESET} branch"
        git switch release/prod
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/prod${RESET} branch\n"
          exit 1
        fi
        ;;
      10)
        echo "Switching to ${GREEN}release/prod-v2${RESET} branch"
        git switch release/prod-v2
        if [ $? -eq 0 ]; then
          :
        else
          printf "Could not switch to ${RED}release/prod-v2${RESET} branch\n"
          exit 1
        fi
        ;;
      *)
        echo "Invalid choice" >&2
        exit 1
        ;;
    esac
  else 
    printf "Git Repo: You're on ${GREEN}$branch${RESET} branch"
  fi
}

#3 function to check if there are uncommitted changes in repo
function commit_status {
  # Check if the current directory is a Git repository
  if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
    :
  else
    echo "This is not a Git repository."
    exit 1
  fi

  # Check if the working tree is clean
  local status
  status=$(git status --porcelain)
  if [ -z "$status" ]; then
    printf "Repo Status: ${GREEN}Working tree is clean.${RESET}\n"
  else
    # Prompt to commit uncommitted changes, default to no
    printf "%b" "${RED}There are uncommitted files.${RESET} Type ${YELLOW}y|Y|yes${RESET} to commit them."
    read -p $'⚠️  Commit uncommitted changes? (yes|no) [no]: ' reply
    reply=${reply:-no}
    case "$reply" in
      yes|Y|y)
        git_commit
        ;;
      *)
        printf "%b" "${YELLOW}Skipping commit of changes.${RESET}\n"
        ;;
    esac
  fi
}

#---------------------------------------#
# init                                  #
#---------------------------------------#
#4 function to create a git repo locally
function git_repo_create {
	read -p $'\nDo you want to create a git repo? (yes|no): ' repo_init
	case "$repo_init" in
		yes|Y|y)
			if [ -d .git ]; then
				printf "%b" "${RED}Current directory already initialised ${RESET}\n"
			else
				printf "%b" "${GREEN}Please enter initial commit message: ${RESET}\n"
				read -r commitMsg
				git init && git add . && git commit -m "$commitMsg"

        # Initialize Git repo
        git init
        git branch -M develop

        # Develop branch
        echo "Creating files in develop branch"
        mkdir "$APP_SRC_DIR"
        touch README.md
        echo "Please delete before first commit. Thank you!" >> "$APP_SRC_DIR/info.txt"
        git add .
        read -p "Enter develop commit message: " cm_develop
        git commit -m "$cm_develop"

        # Main branch
        git branch main
        git checkout main
        echo "Creating files in main branch" 
        mkdir docs
        touch dclm-app .gitignore Makefile
        git add .
        read -p "Enter main commit message: " cm_main  
        git commit -m "$cm_main"

        # bams branch 
        git checkout -b bams
        echo "Creating files in bams branch"
        mkdir -p .github/workflows docs ops
        mkdir -p ops/{dkr,mk,nginx,php,sh}
        touch ops/.gitignore ops/Makefile
        touch .github/deploy.yml
        git add .
        read -p "Enter commit message: " cm_bamsdev
        git commit -m "$cm_bamsdev"

        # release/ec2-dev branch
        git checkout -b release/ec2-dev 
        echo "Committing in release/ec2-dev branch"
        git add .
        read -p "Enter commit message: " cm_ec2dev
        git commit -m "$cm_ec2dev"

        # release/ec2-prod branch
        git checkout -b release/ec2-prod
        echo "Committing in release/ec2-prod branch" 
        git add .
        read -p "Enter commit message: " cm_ec2prod
        git commit -m "$cm_ec2prod"

        # release/k8s-dev branch
        git checkout -b release/k8s-dev
        echo "Committing in release/k8s-dev branch" 
        git add .
        read -p "Enter commit message: " cm_k8sdev
        git commit -m "$cm_k8sdev"

        # release/dev branch
        git checkout -b release/dev
        echo "Committing in release/dev branch" 
        git add .
        read -p "Enter commit message: " cm_dev
        git commit -m "$cm_dev"

        # release/prev branch
        git checkout -b release/prev
        echo "Committing in release/prev branch" 
        git add .
        read -p "Enter commit message: " cm_prev
        git commit -m "$cm_prev"

        # release/k8s-prod branch
        git checkout -b release/k8s-prod
        echo "Committing in release/k8s-prod branch" 
        git add .
        read -p "Enter commit message: " cm_k8sprod
        git commit -m "$cm_k8sprod"

        # release/prod branch
        git checkout -b release/prod
        echo "Committing in release/prod branch" 
        git add .
        read -p "Enter commit message: " cm_prod
        git commit -m "$cm_prod"

			fi
			;;
		no|N|n)
			printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
			;;
		*) \
			printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
			;;
	esac
}

#5 function to create a repository on GitHub
function gh_repo_create {
	read -p $'\nDo you want to create a github repo? (yes|no): ' repo_name
	case "$repo_name" in
		yes|Y|y)
			read -p "Enter GitHub username: " ghUser
			read -p "Enter GitHub repo name: " ghName
      gh="$ghUser/$ghName"
			result="$(gh_repo_check $gh)"
			if [ $result -eq 200 ]; then
				printf "%b" "${RED}GitHub repo exists. I stop here. ${RESET}\n"
			else
				printf "\nWhich type of repository are you creating?:"
				echo "1. Private repo"
				echo "2. Public repo"
				read -p "Enter a number to select your choice: " repoType
				if [ $repoType -eq 1 ]; then
					REPO=private
				elif [ $repoType -eq 2 ]; then
					REPO=public
				else
					echo "Invalid choice"
					exit 0
				fi
				gh repo create ${ghUser}/${ghName} --$REPO --source=. --remote=origin
			fi
			;;
		no|N|n)
			printf "%b" "${GREEN}Okay, thank you...${RESET}\n"
			;;
		*)
			printf "%b" "${GREEN} No choice. Exiting script...${RESET}\n"
			;;
	esac
}

#---------------------------------------#
# app                                   #
#---------------------------------------#
#6 function to commit git repository
function git_commit {
  # function to commit repo with untracked files
  git_commit_new() {
    read -p $'\nDo you want to commit repo files? (yes|no): ' git_commit
    case "$git_commit" in
      yes|Y|y)
        printf "\n${RED}Untracked files found and listed below: ${RESET}\n"
        git status -s
        printf "\n${GREEN}Please enter commit message${RESET}: "
        read msg
        git add -A
        git commit -m "$msg"
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        ;;
    esac
  }

  # function to commit repo with modified files
  git_commit_old() {
    read -p $'\nDo you want to commit repo files? (yes|no): ' git_commit
    case "$git_commit" in
      yes|Y|y)
        printf "\n${RED}Modified files found and listed below: ${RESET}\n"
        git status -s
        printf "\n${GREEN}Please enter commit message${RESET}: "
        read msg
        git commit -am "$msg"
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        ;;
    esac
  }

  if git status --porcelain | grep -q "^??"; then
    git_commit_new
  elif git status --porcelain | grep -qE '[^ADMR]'; then
    git_commit_old
  elif [ -z "$(git status --porcelain)" ]; then
    printf "%b" "${RED} Nothing to commit, thanks...${RESET}\n"
  else
    printf "%b" "${RED} Unknown status. Aborting...${RESET}\n"
    exit 1
  fi
}

#7 build docker image
function docker_build {
  # Login to registry before build (pulling private base images)
  if [ -n "$DL_HARBOR_TOKEN" ] && [ -n "$DL_HARBOR_ROBOT" ] && [ -n "$DL_HARBOR_URL" ]; then
    echo "$DL_HARBOR_TOKEN" | docker login -u "$DL_HARBOR_ROBOT" "$DL_HARBOR_URL" --password-stdin 2>/dev/null
  fi

  # function to purge docker images
  function dkr_purge_image {
    local bypass_prompt=$1
    if [ -z "$bypass_prompt" ]; then
      read -p $'\nDo you want to purge images? (yes|no): ' dkr_purge
    else
      dkr_purge=$bypass_prompt
    fi

    case "$dkr_purge" in
      yes|y)
        if [ "$(docker images -qf "dangling=true")" ]; then
          printf "%b" "${RED}Removing dangling images...${RESET}\n"
          docker image prune -f
        else
          printf "%b" "${GREEN}No dangling images found.${RESET}\n"
        fi
        ;;
      no|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${RED}Invalid choice. Exiting script...${RESET}\n"
        return 1
        ;;
    esac

    if [ $? -eq 0 ]; then
      printf "%b" "${GREEN}Image purge process completed successfully.${RESET}\n"
      return 0
    else
      printf "%b" "${RED}Image purge process encountered errors.${RESET}\n"
      return 1
    fi
  }


  # function to delete docker image
  function dkr_rmi_image {
    local bypass_prompt=$1
    if [ -z "$bypass_prompt" ]; then
      read -p $'\nDo you want to remove image? (yes|no): ' dkr_rmi
    else
      dkr_rmi=$bypass_prompt
    fi

    case "$dkr_rmi" in
      yes|y)
        if docker image inspect $DL_REG_IMAGE &> /dev/null; then
          printf "%b" "${RED}Deleting existing image...${RESET}\n"
          if docker rmi $DL_REG_IMAGE; then
            printf "%b" "${GREEN}Image successfully deleted.${RESET}\n"
          else
            printf "%b" "${RED}Failed to delete image.${RESET}\n"
            return 1
          fi
        else
          printf "%b" "${YELLOW}Image $DL_REG_IMAGE does not exist.${RESET}\n"
        fi
        ;;
      no|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${RED}Invalid choice. Exiting function...${RESET}\n"
        return 1
        ;;
    esac

    if [ $? -eq 0 ]; then
      printf "%b" "${GREEN}Operation successful.${RESET}\n"
      return 0
    else
      printf "%b" "${RED}Operation aborted.${RESET}\n"
      return 1
    fi
  }

  # function to build docker image
  function dkr_build_image {
    local bypass_prompt=$1
    if [ -z "$bypass_prompt" ]; then
      read -p $'\nDo you want to build image? (yes|no): ' dkr_build
    else
      dkr_build=$bypass_prompt
    fi

    case "$dkr_build" in
      yes|y)
        if grep -q "^NODE_ENV=" "$dotenv"; then
          printf "Building ${GREEN}$DL_REG_IMAGE${RESET} image"
          printf "Value of NODE_ENV: $NODE_ENV"
          
          # Link Dockerfile and .dockerignore
          ln -sf ./ops/dkr/Dockerfile Dockerfile
          ln -sf ./ops/dkr/.dockerignore .dockerignore

          # If DL_DKR_ENV is set and non-empty, build --build-arg options and update Dockerfile
          if [ -n "$DL_DKR_ENV" ]; then
            build_args=""
            # Generate the env snippet for the Dockerfile dynamically
            env_snippet="#env"
            IFS=',' read -r -a env_keys <<< "$DL_DKR_ENV"
            for key in "${env_keys[@]}"; do
              key=$(echo "$key" | xargs)  # Trim whitespace
              build_args+=" --build-arg ${key}=${!key}"
              env_snippet+="\nARG ${key}"
            done
            for key in "${env_keys[@]}"; do
              key=$(echo "$key" | xargs)
              env_snippet+="\nENV ${key}=\$${key}"
            done

            # printf "Using build args: $build_args"
            # printf "Updating Dockerfile with:\n$env_snippet"
            
            # Write the snippet to a temporary file
            tmp_snippet=$(mktemp)
            printf "$env_snippet\n" > "$tmp_snippet"
            
            # Insert the snippet after the #env marker, or fallback to COPY ./(src|code) .
            if grep -q '^#env' Dockerfile; then
              sed -i "/#env/r $tmp_snippet" Dockerfile
            else
              sed -i "/COPY \.\\/\\(src\\|code\\) \\./r $tmp_snippet" Dockerfile
            fi
            
            # Remove the temporary snippet file
            rm "$tmp_snippet"
            # docker build $build_args -t $DL_OCI_IMAGE . 2> build_errors.log
            # Check if we should force no-cache build (for CI/CD deployments)
            NO_CACHE_FLAG=""
            if [ "$FORCE_NO_CACHE" = "true" ]; then
              NO_CACHE_FLAG="--no-cache"
              printf "%b" "${YELLOW}🔄 Force no-cache build enabled for deployment${RESET}\n"
            fi
            docker buildx build ${DKR_PLATFORM:+--platform $DKR_PLATFORM} $NO_CACHE_FLAG $build_args -t $DL_REG_IMAGE . 2> build_errors.log
          else
            # docker build -t $DL_OCI_IMAGE . 2> build_errors.log
            # Check if we should force no-cache build (for CI/CD deployments)
            NO_CACHE_FLAG=""
            if [ "$FORCE_NO_CACHE" = "true" ]; then
              NO_CACHE_FLAG="--no-cache"
              printf "%b" "${YELLOW}🔄 Force no-cache build enabled for deployment${RESET}\n"
            fi
            docker buildx build ${DKR_PLATFORM:+--platform $DKR_PLATFORM} $NO_CACHE_FLAG -t $DL_REG_IMAGE . 2> build_errors.log
          fi
        else
          printf "%b" "${GREEN}Building $DL_REG_IMAGE image${RESET}\n"
          ln -sf ./ops/dkr/Dockerfile Dockerfile
          ln -sf ./ops/dkr/.dockerignore .dockerignore
          docker buildx build ${DKR_PLATFORM:+--platform $DKR_PLATFORM} --no-cache -t $DL_REG_IMAGE . 2> build_errors.log
        fi
        if [ $? -eq 0 ]; then
          # if docker image inspect $DL_OCI_IMAGE &> /dev/null; then
          if docker image inspect $DL_REG_IMAGE &> /dev/null; then
            printf "\nDocker image ${GREEN}$DL_REG_IMAGE${RESET} built successfully\n"
            rm -f Dockerfile .dockerignore build_errors.log
            return 0
          else
            printf "%b" "${RED}Error: Image built but not found${RESET}\n"
            cat build_errors.log
            rm -f Dockerfile .dockerignore build_errors.log
            exit 1
          fi
        else
          printf "%b" "${RED}Error: Cannot build image${RESET}\n"
          cat build_errors.log
          rm -f Dockerfile .dockerignore build_errors.log
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${RED}Invalid choice. Exiting function...${RESET}\n"
        return 1
        ;;
    esac
  }

  dkr_purge_image yes
  if [ $? -ne 0 ]; then
    printf "%b" "${RED}Error in purging images.${RESET}\n"
    return 1
  fi

  dkr_rmi_image no
  if [ $? -ne 0 ]; then
    printf "%b" "${RED}Error in removing images.${RESET}\n"
    return 1
  fi

  dkr_build_image yes
  if [ $? -ne 0 ]; then
    printf "%b" "${RED}Error in building image.${RESET}\n"
    return 1
  fi
}


#9 create github workflow
function ga_workflow_env {
  read -p $'\nDo you want to create workflow env? (yes|no): ' ga_workflow
  case "$ga_workflow" in
    yes|Y|y)
      # check if argument is provided
      if [ $# -ne 1 ]; then
        read -p $'\nEnvfile not found... Enter path to env file: ' env
        envfile="$env"
      else
        envfile="$1"
      fi

      vfile="./ops/vars.txt"
      ga_file1="deploy.yml"
      ga_file2="deploy_new.yml"
      ga_dir="./.github/workflows"
      ga="$ga_dir/$ga_file1"
      ga_new="$ga_dir/$ga_file2"

      # Delete vars.txt if it exists
      if [ -f $vfile ]; then
        rm $vfile
      fi

      # Read .env file
      IFS=' ' read -r -a exclude <<< "$DL_ENV_EXCLUDE"
      while IFS= read -r kv; do
        key=$(echo "$kv" | cut -d= -f1)
        if [[ " ${exclude[@]} " =~ " $key " ]]; then
          continue
        fi
        if [[ $key != "" && $key != "#"* ]]; then
          echo "$key" >> $vfile
        fi
      done < <(grep '=' $envfile)

      # Load variables from vars.txt
      while read -r var; do
        vars+=($var)
      done < $vfile

      # Find the "Generate envfile" step in deploy.yml
      envfile_line=$(grep -n "uses: SpicyPizza/create-envfile@v2.0" $ga | cut -d: -f1)
      envfile_line=$((envfile_line+1))
      tail_line=$(grep -n "directory: \${{ env.DL_ENV_SRC }}" $ga | cut -d: -f1)

      # Generate new file with variables
      {
        head -n $((envfile_line)) $ga
        for var in "${vars[@]}"; do
          echo "          envkey_$var: \${{ secrets.$var }}" 
        done
        tail -n +$((tail_line)) $ga
      } > $ga_new

      # Overwrite original 
      mv $ga_new $ga
      rm -f $vfile
      printf "%b" "${GREEN}Actions worklow updated successfully!${RESET}\n"
      ;;
    no|N|n)
      printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
      ;;
    *)
      printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
      ;;
  esac
}

#10 set gh secrets
function gh_secret_set {
  # function to set secrets on private GitHub repo
  function gh_secret_private {
    read -p $'\nDo you want to set secrets on private repo? (yes|no): ' git_push
    case "$git_push" in
      yes|Y|y)
        # check if argument is provided
        if [ $# -ne 1 ]; then
          read -p $'\nEnvfile not found... Enter path to env file: ' env
          envfile="$env"
        else
          envfile="$1"
        fi

        # Set number of retries and delay between retries  
        MAX_RETRIES=3
        RETRY_DELAY=2
        # Helper function to retry command on failure
        retry() {
          local retries=$1
          shift
          local count=0
          until "$@"; do
            exit=$?
            count=$(($count + 1))
            if [ $count -lt $retries ]; then
              echo "Command failed! Retrying in $RETRY_DELAY seconds..."
              sleep $RETRY_DELAY 
            else
              echo "Failed after $count retries."
              return $exit
            fi
          done 
          return 0
        }

        printf "%b" "${GREEN}Setting secrets...${RESET}\n"
        # Read the .env file and set the secrets
        retry $MAX_RETRIES gh secret set -f "$envfile"
        # Check return code and output result
        if [ $? -eq 0 ]; then
          printf "Secrets set successfully\n"
        else
          printf "Error setting secrets\n"
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }

  # function to delete secrets on private GitHub repo
  function gh_secret_private_rm {
    read -p $'\nDo you want to delete secrets on private repo? (yes|no): ' git_push
    case "$git_push" in
      yes|Y|y)
        printf "%b" "${GREEN}Deleting private repo secrets...${RESET}\n"
        # Get list of secrets 
        secrets=$(gh secret list --repo ${DL_GH_OWNER_REPO} --json name --jq '.[].name')

        # Read secrets into array
        SECRETS=()
        while IFS= read -r secret; do
          SECRETS+=("$secret") 
        done <<< "$secrets"

        # Delete secrets
        for secret in "${SECRETS[@]}"; do
          gh secret delete --repo ${DL_GH_OWNER_REPO} "$secret"
        done

        # Check return code and output result
        if [ $? -eq 0 ]; then
          printf "Secrets deleted successfully\n"
        else
          printf "Error deleting secrets\n"
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }

  # function to set secrets on public GitHub repo
  function gh_secret_public {
    read -p $'\nDo you want to set secrets on public repo? (yes|no): ' git_push
    case "$git_push" in
      yes|Y|y)
        # check if argument is provided
        if [ $# -ne 1 ]; then
          read -p $'\nEnvfile not found... Enter path to env file: ' env
          envfile="$env"
        else
          envfile="$1"
        fi

        # Set number of retries and delay between retries  
        MAX_RETRIES=3
        RETRY_DELAY=2
        # Helper function to retry command on failure
        retry() {
          local retries=$1
          shift
          local count=0
          until "$@"; do
            exit=$?
            count=$(($count + 1))
            if [ $count -lt $retries ]; then
              printf "Command failed! Retrying in $RETRY_DELAY seconds..."
              sleep $RETRY_DELAY 
            else
              printf "Failed after $count retries."
              return $exit
            fi
          done 
          return 0
        }

        printf "%b" "${GREEN}Setting secrets...${RESET}\n"
        # Check the DL_GH_BRANCH variable
        if [ "$DL_GH_BRANCH" = "release/ec2-prod" ]; then
          env="prod"
        elif [ "$DL_GH_BRANCH" = "release/ec2-dev" ]; then
          env="dev"
        else
          echo "DL_GH_BRANCH value not what is expected!"
          exit 0
        fi
        # Read the .env file and set the secrets
        retry $MAX_RETRIES gh secret set -f "$envfile" -e "$env"
        # Check return code and output result
        if [ $? -eq 0 ]; then
          printf "Secrets set successfully\n"
        else
          printf "Error setting secrets\n"
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }

  # function to delete secrets on public GitHub repo
  function gh_secret_public_rm {
    read -p $'\nDo you want to delete secrets on public repo? (yes|no): ' git_push
    case "$git_push" in
      yes|Y|y)
        printf "%b" "${GREEN}Deleting public repo secrets...${RESET}\n"
        # Check the DL_GH_BRANCH variable
        if [ "$DL_GH_BRANCH" = "release/ec2-prod" ]; then
          env="prod"
        elif [ "$DL_GH_BRANCH" = "release/ec2-dev" ]; then
          env="dev"
        else
          echo "Aha! No need then..."
          exit 0
        fi

        # Get list of secrets 
        secrets=$(gh secret list --repo ${DL_GH_OWNER_REPO} --env $env --json name --jq '.[].name')

        # Read secrets into array
        SECRETS=()
        while IFS= read -r secret; do
          SECRETS+=("$secret") 
        done <<< "$secrets"

        # Delete secrets
        for secret in "${SECRETS[@]}"; do
          gh secret delete --repo ${DL_GH_OWNER_REPO} --env $env "$secret"
        done

        # Check return code and output result
        if [ $? -eq 0 ]; then
          printf "Secrets deleted successfully\n"
        else
          printf "Error deleting secrets\n"
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }

  # function to set variables on private GitHub repo
  function gh_variable_private {
    read -p $'\nDo you want to set variables on private repo? (yes|no): ' git_push
    case "$git_push" in
      yes|Y|y)
        printf "%b" "${GREEN}Setting variables...${RESET}\n"
        vhost=${DL_NGX_VHOST}
        gh variable set DL_NGX_VHOST < "$vhost"
        # Check return code and output result
        if [ $? -eq 0 ]; then
          printf "Variables set successfully\n"
        else
          printf "Error setting variables\n"
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }

  # function to delete variables on private GitHub repo
  function gh_variable_private_rm {
    read -p $'\nDo you want to delete variables on private repo? (yes|no): ' git_push
    case "$git_push" in
      yes|Y|y)
        printf "%b" "${GREEN}Deleting variables...${RESET}\n"
        gh variable delete DL_NGX_VHOST --repo ${DL_GH_OWNER_REPO}

        # Check return code and output result
        if [ $? -eq 0 ]; then
          printf "Variables deleted successfully\n"
        else
          printf "Error deleting variables\n"
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }

  # function to set variables on public GitHub repo
  function gh_variable_public {
    read -p $'\nDo you want to set variables on public repo? (yes|no): ' git_push
    case "$git_push" in
      yes|Y|y)
        printf "%b" "${GREEN}Setting variables...${RESET}\n"
        # Check the DL_GH_BRANCH variable
        if [ "$DL_GH_BRANCH" = "release/ec2-prod" ]; then
          env="prod"
        elif [ "$DL_GH_BRANCH" = "release/ec2-dev" ]; then
          env="dev"
        else
          echo "Haa! No need then..."
          exit 0
        fi
        vhost=${DL_NGX_VHOST}
        gh variable set DL_NGX_VHOST < "$vhost" -e"$env"
        # Check return code and output result
        if [ $? -eq 0 ]; then
          printf "Variables set successfully\n"
        else
          printf "Error setting variables\n"
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }

  # function to delete variables on public GitHub repo
  function gh_variable_public_rm {
    read -p $'\nDo you want to delete variables on public repo? (yes|no): ' git_push
    case "$git_push" in
      yes|Y|y)
        printf "%b" "${GREEN}Deleting variables...${RESET}\n"
        # Check the DL_GH_BRANCH variable
        if [ "$DL_GH_BRANCH" = "release/ec2-prod" ]; then
          env="prod"
        elif [ "$DL_GH_BRANCH" = "release/ec2-dev" ]; then
          env="dev"
        else
          echo "Haa! No need then..."
          exit 0
        fi

        gh variable delete DL_NGX_VHOST --repo ${DL_GH_OWNER_REPO} --env $env

        # Check return code and output result
        if [ $? -eq 0 ]; then
          printf "Variables deleted successfully\n"
        else
          printf "Error deleting variables\n"
          exit 1
        fi
        ;;
      no|N|n)
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }

  check="$(gh_repo_view)"
  if [ "$check" == "private" ]; then
    gh_secret_private_rm
    gh_secret_private $DL_APP_ENV_FILE
    gh_variable_private_rm
    gh_variable_private
  elif [ "$check" == "public" ]; then
    gh_secret_public_rm
    gh_secret_public $DL_APP_ENV_FILE
    gh_variable_public_rm
    gh_variable_public
  else
    echo "Could not set secrets. Something is wrong!"
    exit 1
  fi
}

#11 push commit to remote git server
function git_repo_push {
  read -p $'\nDo you want to push your commit to origin? (yes|no): ' git_push
  case "$git_push" in
    yes|Y|y)
      printf "%b" "${GREEN}Pushing commit to GitHub...${RESET}\n"
      git push
      ;;
    no|N|n)
      printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
      ;;
    *)
      printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
      exit 1
      ;;
  esac
}

function docker_push {
  local bypass_prompt=$1

  if [ -z "$bypass_prompt" ]; then
      read -p $'\nDo you want to push docker image? (yes|no): ' dkr_push
  else
      dkr_push=$bypass_prompt
  fi

  case "$dkr_push" in
    yes|y)
      # echo ${DL_DK_TOKEN} | docker login -u ${DL_DK_HUB} --password-stdin
      if echo ${DL_HARBOR_TOKEN} | docker login -u ${DL_HARBOR_ROBOT} ${DL_HARBOR_URL} --password-stdin; then
        if docker push $DL_REG_IMAGE; then
          printf "%b" "${GREEN}Docker image successfully pushed.${RESET}\n"
        else
          printf "%b" "${RED}Failed to push Docker image${RESET}\n"
          return 1
        fi
      else
        printf "%b" "${RED}Failed to login to Docker registry${RESET}\n"
        exit 1
      fi
      ;;
    no|n)
      printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
      ;;
    *)
      printf "%b" "${RED}Invalid choice. Exiting function...${RESET}\n"
      return 1
      ;;
  esac
}


#---------------------------------------#
# github actions                        #
#---------------------------------------#
#13 create dns record on aws route53
function create_route53_record {
  # Load environment variables from a .env file
  # Variables from .env or directly assigned
  HOSTED_ZONE_ID="$DL_AWS_R53_ZONEID"
  DNS_NAME="$DL_APP_URL2"
  DNS_TYPE="${DNS_TYPE:-A}"
  DNS_TTL="${DNS_TTL:-60}"
  DNS_VALUE="$DL_AWS_R53_IP"

  # Function to check if DNS record exists and get its current value
  check_dns_record() {
    local hosted_zone_id=$1
    local dns_name=$2
    local dns_type=$3

    aws route53 list-resource-record-sets \
      --profile dclmict \
      --hosted-zone-id "$hosted_zone_id" \
      --query "ResourceRecordSets[?Name == '$dns_name.' && Type == '$dns_type']" \
      --output json
  }

  # Function to create or update DNS record
  modify_dns_record() {
    local hosted_zone_id=$1
    local dns_name=$2
    local dns_type=$3
    local dns_ttl=$4
    local dns_value=$5
    local action=$6

    change_batch=$(jq -n --arg action "$action" --arg name "$dns_name." --arg type "$dns_type" --arg ttl "$dns_ttl" --arg value "$dns_value" '{
      "Comment": "Modify record via script",
      "Changes": [
        {
          "Action": $action,
          "ResourceRecordSet": {
            "Name": $name,
            "Type": $type,
            "TTL": ($ttl | tonumber),
            "ResourceRecords": [
              {
                "Value": $value
              }
            ]
          }
        }
      ]
    }')

    aws route53 change-resource-record-sets \
      --profile dclmict \
      --hosted-zone-id "$hosted_zone_id" \
      --change-batch "$change_batch"
  }

  # Check if DNS record exists and get its current value
  record_info=$(check_dns_record "$HOSTED_ZONE_ID" "$DNS_NAME" "$DNS_TYPE")
  
  if [ -z "$record_info" ]; then
    echo "Error: Could not retrieve DNS record information. Please check your AWS CLI configuration."
    return 1
  fi

  record_count=$(echo "$record_info" | jq '. | length')
  
  if [ "$record_count" -gt 0 ]; then
    current_value=$(echo "$record_info" | jq -r '.[0].ResourceRecords[0].Value')
    if [ "$current_value" = "$DNS_VALUE" ]; then
      echo "DNS record $DNS_NAME of type $DNS_TYPE already exists with the correct value."
    else
      echo "DNS record $DNS_NAME of type $DNS_TYPE exists but has a different value. Updating it."
      if modify_dns_record "$HOSTED_ZONE_ID" "$DNS_NAME" "$DNS_TYPE" "$DNS_TTL" "$DNS_VALUE" "UPSERT"; then
        echo "DNS record $DNS_NAME of type $DNS_TYPE updated successfully."
      else
        echo "Failed to update DNS record $DNS_NAME of type $DNS_TYPE."
        return 1
      fi
    fi
  else
    echo "DNS record $DNS_NAME of type $DNS_TYPE does not exist. Creating it."
    if modify_dns_record "$HOSTED_ZONE_ID" "$DNS_NAME" "$DNS_TYPE" "$DNS_TTL" "$DNS_VALUE" "CREATE"; then
      echo "DNS record $DNS_NAME of type $DNS_TYPE created successfully."
    else
      echo "Failed to create DNS record $DNS_NAME of type $DNS_TYPE."
      return 1
    fi
  fi
}


#14 create directory to deploy app  
function create_app_dir {
  # Navigate into the docker directory
  cd "$DL_APP_DK_DIR"

  # Check if target folder exists
  if [ ! -d "$DL_APP_NAME" ]; then
    # Folder doesn't exist, create it
    echo "Creating folder $DL_APP_NAME"  
    mkdir -p "$DL_APP_NAME"
  else
    # Folder exists, print message
    echo "Folder $DL_APP_NAME already exists"
  fi
}

#15 clone app repository 
function clone_app_repo {
  # Check app dir
  printf "\nChecking if app directory exists.."
  if [ ! -d "$DL_APP_DIR" ]; then
    echo "Directory not found, creating..."
    mkdir -p "$DL_APP_DIR"
  else
    echo "Directory already exists."
  fi

  # Enter into app dir
  printf "\nEntering app directory.."
  cd "$DL_APP_DIR"

  # Clone app repo
  printf "\nCloning latest repo changes.."
  if [ ! -d .git ]; then
    echo "App repo not found. Cloning..."
    git clone "$DL_GH_REPO" . \
    && git switch "$DL_GH_BRANCH"
  else
    echo "App repo exists..."
    git fetch --all \
    && git switch "$DL_GH_BRANCH"
  fi
}

#16 create nginx vhost for app url
function create_nginx_vhost {
  # enter directory
  cd "$DL_ENV_DEST"

  # another way
  ngxx="vhost.conf"
  ngx=$(cat "$ngxx")
  eval "VHOST=\"$ngx\""

  # Create a temporary file with the provided configuration
  printf "\nCreating temporary file..."
  temp_file="$(mktemp)"
  echo "$VHOST" > "$temp_file"

  # Extract the block identifier (the first line of the provided config)
  printf "\nExtracting the vhost block identifier..."
  block_identifier=$(head -n 1 "$temp_file")
  printf "Content of block identifier:\n$block_identifier"

  # Check if the vhost configuration exists
  printf "\nChecking if vhost config exists..."
  if grep -qF "$block_identifier" "$DL_HOST_NGX_DIR/$DL_NGX_CONF"; then
    printf "Vhost config already exists."

    # Get the existing vhost block that matches the block identifier
    printf "\nExtracting existing vhost config..."
    end_pattern="^}"
    existing_block="$(sed -n "/$block_identifier/,/$end_pattern/p" "$DL_HOST_NGX_DIR/$DL_NGX_CONF")"
    printf "Content of existing vhost:\n$existing_block"

    # Compare the existing block with the provided configuration
    printf "\nComparing existing vhost config with provided vhost config..."
    if diff -q <(echo "$VHOST") <(echo "$existing_block"); then
      echo "Configuration matches. No action needed."
    else
      # Delete the existing vhost configuration and append the provided config
      printf "\nDeleting existing vhost config..."
      sed -i "/$block_identifier/,/$end_pattern/d" "$DL_HOST_NGX_DIR/$DL_NGX_CONF"
      printf "\nUpdating vhost config..."
      printf "\n$VHOST" | sudo tee -a "$DL_HOST_NGX_DIR/$DL_NGX_CONF"
      echo "Nginx vhost configuration updated."

      # Test Nginx configuration for syntax errors
      sudo nginx -t

      # Reload Nginx if the configuration is valid
      if [ $? -eq 0 ]; then
        sudo nginx -s reload
        sudo systemctl status nginx
      else
        echo "Nginx configuration is invalid. Not reloading Nginx."
      fi
    fi
  else
    echo "Nginx vhost configuration not found."
    echo "Creating Nginx vhost entry for $DL_APP_URL..."
    printf "\n$VHOST" | sudo tee -a "$DL_HOST_NGX_DIR/$DL_NGX_CONF"

    # Test Nginx configuration for syntax errors
    sudo nginx -t

    # Reload Nginx if the configuration is valid
    if [ $? -eq 0 ]; then
      sudo nginx -s reload
      sudo systemctl status nginx
    else
      echo "Nginx configuration is invalid. Not reloading Nginx."
    fi  
  fi

  # Remove temporary files
  printf "\nRemoving temporary files..."
  rm -f "$temp_file"
  rm -f "$ngxx"
}

#17 deploy app on prod server
function ga_deploy_app {
  # Enter app dir
  printf "\nEntering app directory..."
  cd "$DL_APP_DIR"

  # Pull repo changes
  printf "\nDownloading latest repo changes..."
  make new

  # Drop running container
  printf "\nDropping running container..."
  make down

  # Start new container
  printf "\nLaunching latest app version..."
  make run
}

#---------------------------------------#
# utils                                 #
#---------------------------------------#
#18 function to copy .env based on environment
function copy_app_env {
  # Define the source and destination directories
  src_dir="./ops"
  dest_dir="./${APP_SRC_DIR}"

  # Define environment file
  dest_env=".env"
  default_env_file="bams.env"

  # Display the options
  echo "Please select an environment:"
  echo "1) dclm-dev"
  echo "2) dclm-prod"
  echo "3) Custom env"

  # Read the user's selection
  read -p "Select an option or press enter to copy default: " selection

  # Handle the user's selection
  case $selection in
    1)
      env_file="dclm-dev.env"
      ;;
    2)
      env_file="dclm-prod.env"
      ;;
    3)
      read -p "Enter the name of the custom environment file: " env_file
      ;;
    "")
      env_file=$default_env_file
      ;;
    *)
      printf "Invalid option. Please select 1, 2, or 3\n"
      ;;
  esac

  # Copy the environment file
  cp "${src_dir}/${env_file}" "${dest_dir}/${dest_env}"

  # Check if the copy was successful
  if [ $? -eq 0 ]; then
    printf "Environment file copied successfully.\n"
  else
    printf "Failed to copy environment file. Exiting.\n"
    exit 1
  fi
}

#19 function to scan GitHub repo
function git_repo_scan {
	read -p $'\nDo you want to scan this repo? (yes|no): ' repo_scan
	case "$repo_scan" in
		yes|Y|y)
			printf "%b" "${GREEN}Scanning repo for secrets...${RESET}\n"
			ggshield secret scan repo .
			;;
		no|N|n)
			printf "%b" "${GREEN}Okay. Thank you...${RESET}\n"
			exit 0
			;;
		*)
			printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
			exit 1
			;;
	esac  
}

#20 function to rename local git repo
function git_repo_rename {
  printf "I love JESUS"
}

#21 function to rename GitHub repo
function gh_repo_rename {
  read -p "Enter GitHub username: " gh_user

  function repo_name {
    read -p "Enter current repository name: " gh_repo
    read -p "Enter new repository name: " new_name
    # API to rename repo
    API_ENDPOINT="https://api.github.com/repos/${gh_user}/${gh_repo}"

    # Make API call to rename repo
    curl \
      -X PATCH \
      -H "Authorization: token ${DL_GH_TOKEN}" \
      -d '{"name":"'"${new_name}"'"}' \
      ${API_ENDPOINT}

    if [ $? -eq 0 ]; then
      printf "Repository renamed successfully!\n"
    else
      printf "Error renaming repository\n" >&2
      exit 1
    fi

    # run function to change repo remote url
    repo_url
  }

  function repo_url {
    read -p $'\nAbout to change repo"s remote url. Proceed? (yes|no): ' user_grant
    case "$user_grant" in
      yes|Y|y)
        read -p "Enter new repository name: " NEW_NAME
        git remote set-url origin git@github.com:${GH_USER}/${NEW_NAME}.git
        git remote -v
        if [ $? -eq 0 ]; then
          echo "Remote url successfully set!"
        else
          echo "Error renaming repository" >&2
          exit 1
        fi
        ;; 
      no|N|n) 
        printf "%b" "${GREEN}Alright. Thank you...${RESET}\n"
        exit 0
        ;;
      *)
        printf "%b" "${GREEN}No choice. Exiting script...${RESET}\n"
        exit 1
        ;;
    esac
  }
  # Select action
  echo "Select action:"
  echo "1) Rename repo name on Github"
  echo "2) Rename repo remote url"
  read action_selection
  if [ $action_selection -eq 1 ]; then
    repo_name
  elif [ $action_selection -eq 2 ]; then
    repo_url
  else
    echo "Invalid selection"
    exit 1  
  fi
}

#22 function to check if GitHub repo exists
function gh_repo_check {
  # check if argument is provided
  if [ $# -ne 1 ]; then
    read -p "Enter GitHub username: " ghUser
		read -p "Enter GitHub repo name: " ghName
    repo="${ghUser}/${ghName}"
  else
    repo=$1
  fi

  status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token ${DL_GH_TOKEN}" "https://api.github.com/repos/$repo")

  code1=200
  code2=404

  if [ $status_code -eq 200 ]; then
    echo $code1
  elif [ $status_code -eq 404 ]; then
    echo $code2
  else
    echo "Status code: $status_code" >&2
    exit 1
  fi
}

#23 function to check if GitHub repo is private/public
function gh_repo_view {
  code1=private
  code2=public
  view=$(gh repo view $DL_GH_OWNER_REPO --json isPrivate -q .isPrivate 2>/dev/null)
	if [ "$view" = "true" ]; then
		echo $code1
	else
		echo $code2
	fi
}


#---------------------------------------#
# git push                  #
#---------------------------------------#
function git_push {
  git_branch
  ga_workflow_env $dotenv
  commit_status
  gh_secret_set
  git_repo_push
}


# 24 function to create environment secrets on gitea repo
function gitea_env {
  # source $dotenv
  which=$1

  # Function to create a secret
  create_secret() {
    local secret_name="$1"
    local secret_value="$2"

    # Data payload for creating a secret
    local data=$(printf '{"data": "%s"}' "$secret_value")

    # Determine the correct API endpoint based on the scope
    # if [ "$3" = "org" ]; then
    #   endpoint="$DL_GITEA_API_URL/orgs/$DL_GITEA_ORG/actions/secrets/$secret_name"
    # elif [ "$3" = "repo" ]; then
    #   endpoint="$DL_GITEA_API_URL/repos/$DL_GITEA_OWNER/$DL_REPO_NAME/actions/secrets/$secret_name"
    # else
    #   echo "Invalid scope: $3"
    #   return 1
    # fi

    endpoint="$DL_GITEA_API_URL/repos/$DL_GITEA_OWNER/$DL_REPO_NAME/actions/secrets/$secret_name"

    # Debug: Print the data payload and endpoint
    # echo "Creating secret '$secret_name' with endpoint '$endpoint'"
    # echo "Payload: $data"

    # Make the API request to create the secret
    response=$(curl --cacert ~/dev/keys/dclm.hq/dclm.hq.crt -s -o /dev/null -w "%{http_code}" -X PUT "$endpoint" \
      --header "Authorization: token $DL_GITEA_TOKEN" \
      --header "Content-Type: application/json" \
      --data-raw "$data")

    if [ "$response" = 201 ] || [ "$response" = 204 ]; then
      echo "Secret '$secret_name' created successfully."
    else
      echo "Failed to create secret '$secret_name'. HTTP response code: $response"
    fi
  }

  # Read the .env file and create secrets
  while IFS='=' read -r secret_name secret_value || [ -n "$secret_name" ]; do
    # Skip empty lines and comments
    if [ -z "$secret_name" ] || [[ "$secret_name" == \#* ]]; then
      continue
    fi

    # Evaluate the value to replace variables with their actual values
    eval expanded_secret=\$$secret_name
    create_secret "$secret_name" "$expanded_secret"
    # create_secret "$secret_name" "$expanded_secret" "$which"
  done < "$dotenv"
}


function mikrotik_dns {
  # source $dotenv

  # Set the command to check for the DNS name
  CHECK="/ip dns static print where name=$MK_DNS_NAME"

  # Set the command to run on the Mikrotik server
  CREATE="/ip dns static add address=$MK_DNS_ADDRESS comment=\"$MK_DNS_COMMENT\" name=$MK_DNS_NAME"

  # Check if the DNS entry already exists
  if [ "$(hostname)" == "bams" ]; then
    ssh -i ~/dev/keys/dles $MK_USER@$MK_HOST "$CHECK" | grep $MK_DNS_NAME > /dev/null

    if [ $? -eq 0 ]; then
      echo "Domain: ${MK_DNS_NAME} already exists. No action taken."
    else
      # Add the DNS entry
      ssh -i ~/dev/keys/dles $MK_USER@$MK_HOST "$CREATE"

      if [ $? -eq 0 ]; then
        echo "Domain: ${MK_DNS_NAME} has been added successfully"
      else
        echo "Failed to add domain ${MK_DNS_NAME}"
        exit 1
      fi
    fi
  else
    # Example SSH key stored in an environment variable
    SSH_CERT="$DLES_SSH_KEY"
    echo $SSH_CERT

    # Path to temporary file for the SSH key
    TMP_SSH_KEY=$(mktemp)

    # Write the SSH key to the temporary file
    echo "$SSH_CERT" > "$TMP_SSH_KEY"
    chmod 600 "$TMP_SSH_KEY"

    echo $TMP_SSH_KEY
    # Use the temporary SSH key to execute the command on the remote host
    ssh -i "$TMP_SSH_KEY" -T -o "StrictHostKeyChecking=no" "$MK_USER@$MK_HOST" "$CHECK" | grep $MK_DNS_NAME > /dev/null

    if [ $? -eq 0 ]; then
      echo "Domain: ${MK_DNS_NAME} already exists. No action taken."
    else
      # Add the DNS entry
      ssh -i "$TMP_SSH_KEY" -T -o "StrictHostKeyChecking=no" $MK_USER@$MK_HOST "$CREATE"

      if [ $? -eq 0 ]; then
        echo "Domain: ${MK_DNS_NAME} has been added successfully"
      else
        echo "Failed to add domain ${MK_DNS_NAME}"
        exit 1
      fi
    fi

    # Clean up by removing the temporary SSH key file
    rm "$TMP_SSH_KEY"
  fi
}

function gitea_workflow_secret {
  # Path to the .env file
  # dotenv='./.env'
  deploy_yml='./.gitea/workflows/deploy.yml'

  # Check if the .env file exists
  # if [ ! -f "$dotenv" ]; then
  #   echo ".env file not found!"
  #   exit 1
  # fi

  # Initialize an empty array to store the variable names
  env_vars=()

  # Read the .env file line by line
  while IFS= read -r line; do
    # Skip empty lines and comments
    if [ -z "$line" ] || [[ "$line" == \#* ]]; then
      continue
    fi

    # Extract the variable name
    var_name=$(echo "$line" | cut -d'=' -f1)
    
    # Add the variable name to the array
    env_vars+=("$var_name")
  done < "$dotenv"

  # Convert the array to a string in the desired format
  env_vars_string='          secrets=('  # 10 spaces before 'secrets=('
  for var in "${env_vars[@]}"; do
    env_vars_string+="\"$var\" "
  done
  env_vars_string=${env_vars_string% }')'

  # Escape any special characters in the replacement string for sed
  escaped_env_vars_string=$(printf '%s\n' "$env_vars_string" | sed 's/[&/\]/\\&/g')

  # Replace the line starting with 'secrets=(' in deploy.yml
  if [ -f "$deploy_yml" ]; then
    # Use a temporary file for the substitution
    tmpfile=$(mktemp)
    sed "s/^ *secrets=(\"DL_APP1\".*/$escaped_env_vars_string/" "$deploy_yml" > "$tmpfile" && mv "$tmpfile" "$deploy_yml"
    
    echo "Updated $deploy_yml with new secrets."
  else
    echo "$deploy_yml not found!"
    exit 1
  fi

}


#---------------------------------------#
# k8s                                   #
#---------------------------------------#
function set_kube_context() {
  local context=$1
  local namespace=$2
  if [ -z "$context" ]; then
    echo "Usage: set_kube_context <context-name> <namespace>"
    return 1
  fi

  # Check if the context exists
  if ! kubectl config get-contexts -o name | grep -q "^$context$"; then
    echo "Context '$context' does not exist. Available contexts are:"
    kubectl config get-contexts -o name
    return 1
  fi

  # Set the context
  kubectl config use-context "$context"
  
  # If namespace is provided, set it
  if [ -n "$namespace" ]; then
    kubectl config set-context --current --namespace="$namespace"
    echo "Context set to '$context' with namespace '$namespace'"
  else
    echo "Context set to '$context'"
  fi

  # Display current context info
  # kubectl config get-contexts --current
}

function is_pod_terminating() {
  local namespace=$1
  local pod_pattern=$2
  
  if [ -z "$namespace" ] || [ -z "$pod_pattern" ]; then
    echo "Usage: is_pod_terminating <namespace> <pod_pattern>"
    return 1
  fi

  local pod_name=$(kubectl get pods -n $namespace | grep $pod_pattern | awk '{print $1}')
  
  if [ -z "$pod_name" ]; then
    echo "No pod matching '$pod_pattern' found in namespace '$namespace'"
    return 1
  fi

  local deletion_timestamp=$(kubectl get pod -n $namespace $pod_name -o jsonpath='{.metadata.deletionTimestamp}')
  local phase=$(kubectl get pod -n $namespace $pod_name -o jsonpath='{.status.phase}')

  if [ -n "$deletion_timestamp" ] || [ "$phase" = "Terminating" ]; then
    echo "Pod $pod_name is terminating"
    return 0
  else
    echo "Pod $pod_name is not terminating"
    return 1
  fi
}

function delete_pod() {
  local namespace=$1
  local pod_pattern=$2
  
  if [ -z "$namespace" ] || [ -z "$pod_pattern" ]; then
    echo "Usage: delete_pod <namespace> <pod_pattern>"
    return 1
  fi

  local pod_name=$(kubectl get pods -n $namespace | grep $pod_pattern | awk '{print $1}')
  
  if [ -z "$pod_name" ]; then
    echo "No pod matching '$pod_pattern' found in namespace '$namespace'"
    return 1
  fi

  if is_pod_terminating $namespace $pod_pattern; then
    echo "Pod $pod_name is already terminating. No action taken."
    return 0
  else
    echo "Deleting pod: $pod_name"
    kubectl delete pod -n $namespace $pod_name
    if [ $? -eq 0 ]; then
      echo "Pod $pod_name deleted successfully"
      return 0
    else
      echo "Failed to delete pod $pod_name"
      return 1
    fi
  fi
}

function k8s_delete_pod {
  # check branch
  branch=$(git rev-parse --abbrev-ref HEAD)

  if [[ "$branch" = "release/dev" ]] || [[ "$branch" = "release/dev-v2" ]]; then
    delete_pod $K8S_NAMESPACE $DL_APP_NAME
  fi

  if [[ "$branch" = "release/prev" ]] || [[ "$branch" = "release/prev-v2" ]]; then
    delete_pod $K8S_NAMESPACE $DL_APP_NAME
  fi

  if [[ "$branch" = "release/prod-v2" ]]; then
    delete_pod $K8S_NAMESPACE $DL_APP_NAME
  fi
}

function k8s_app_mnf {
  # Script to generate k8s manifest file from a template file
  # Usage: ./app.sh .env template.yml

  ENVFILE=$1
  OUTPUT_FILE=$2

  # Load the envfile
  if [[ -f "$ENVFILE" ]]; then
    source "$ENVFILE"
  else
    echo "Env file not found!"
    exit 1
  fi

  # Validate required environment variables
  if [[ -z "$K8S_CONTAINER_PORTS" ]]; then
    echo "K8S_CONTAINER_PORTS must be set in the .env file!"
    exit 1
  fi

  # Convert comma-separated K8S_CONTAINER_PORTS to an array
  IFS=',' read -r -a CONTAINER_PORTS <<< "$K8S_CONTAINER_PORTS"

  # If K8S_SERVICE_PORTS is provided, use it; otherwise, use CONTAINER_PORTS
  if [[ -n "$K8S_SERVICE_PORTS" ]]; then
    IFS=',' read -r -a SERVICE_PORTS <<< "$K8S_SERVICE_PORTS"
    if [[ ${#SERVICE_PORTS[@]} -ne ${#CONTAINER_PORTS[@]} ]]; then
      echo "Error: Number of K8S_SERVICE_PORTS must match K8S_CONTAINER_PORTS!"
      exit 1
    fi
  else
    SERVICE_PORTS=("${CONTAINER_PORTS[@]}")
  fi

  # Validate port numbers
  for port in "${CONTAINER_PORTS[@]}" "${SERVICE_PORTS[@]}"; do
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
      echo "Error: Invalid port number '$port'. Ports must be numeric!"
      exit 1
    fi
  done

  # Generate container ports YAML
  CONTAINER_PORTS_YAML_LINES=()
  for port in "${CONTAINER_PORTS[@]}"; do
    CONTAINER_PORTS_YAML_LINES+=("        - containerPort: $port")
  done
  CONTAINER_PORTS_YAML=$(IFS=$'\n'; echo "${CONTAINER_PORTS_YAML_LINES[*]}")

  # Generate service ports YAML
  SERVICE_PORTS_YAML_LINES=()
  for i in "${!CONTAINER_PORTS[@]}"; do
    SERVICE_PORTS_YAML_LINES+=("  - port: ${SERVICE_PORTS[$i]}")
    SERVICE_PORTS_YAML_LINES+=("    targetPort: ${CONTAINER_PORTS[$i]}")
    SERVICE_PORTS_YAML_LINES+=("    name: http-${CONTAINER_PORTS[$i]}")
  done
  SERVICE_PORTS_YAML=$(IFS=$'\n'; echo "${SERVICE_PORTS_YAML_LINES[*]}")

  # Generate readinessProbe YAML
  READINESS_PROBE_YAML=""
  if [[ -n "$K8S_READINESS_PATH" && -n "$K8S_READINESS_PORT" && -n "$K8S_READINESS_INITIAL_DELAY" && -n "$K8S_READINESS_PERIOD" ]]; then
    if ! [[ "$K8S_READINESS_PORT" =~ ^[0-9]+$ ]]; then
      echo "Error: Invalid K8S_READINESS_PORT '$K8S_READINESS_PORT'. Must be numeric!"
      exit 1
    fi
    port_found=false
    for port in "${CONTAINER_PORTS[@]}"; do
      if [[ "$port" == "$K8S_READINESS_PORT" ]]; then
        port_found=true
        break
      fi
    done
    if [[ "$port_found" == false ]]; then
      echo "Error: K8S_READINESS_PORT '$K8S_READINESS_PORT' must match one of K8S_CONTAINER_PORTS!"
      exit 1
    fi
    if ! [[ "$K8S_READINESS_INITIAL_DELAY" =~ ^[0-9]+$ ]] || ! [[ "$K8S_READINESS_PERIOD" =~ ^[0-9]+$ ]]; then
      echo "Error: K8S_READINESS_INITIAL_DELAY and K8S_READINESS_PERIOD must be numeric!"
      exit 1
    fi
    READINESS_PROBE_YAML_LINES=(
      "        readinessProbe:"
      "          httpGet:"
      "            path: ${K8S_READINESS_PATH}"
      "            port: ${K8S_READINESS_PORT}"
      "          initialDelaySeconds: ${K8S_READINESS_INITIAL_DELAY}"
      "          periodSeconds: ${K8S_READINESS_PERIOD}"
    )
    READINESS_PROBE_YAML=$(IFS=$'\n'; echo "${READINESS_PROBE_YAML_LINES[*]}")
  fi

  # Node selector YAML (optional)
  NODE_SELECTOR_YAML=""
  if [[ -n "${K8S_NODE_SELECTOR:-}" ]]; then
    NODE_SELECTOR_YAML="      nodeSelector:
        ${K8S_NODE_SELECTOR}"
  fi

  # Burst node selector YAML (for spot replicas)
  BURST_NODE_SELECTOR_YAML=""
  if [[ -n "${K8S_BURST_NODE_SELECTOR:-}" ]]; then
    BURST_NODE_SELECTOR_YAML="      nodeSelector:
        ${K8S_BURST_NODE_SELECTOR}"
  fi

  # Write template to file
  cat << EOF > "$OUTPUT_FILE"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DL_APP_NAME}
  namespace: ${K8S_NAMESPACE}
spec:
  replicas: ${K8S_MIN_REPLICA}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: ${K8S_RU_SURGE}
      maxUnavailable: ${K8S_RU_UNAVAILABLE}
  selector:
    matchLabels:
      app: ${DL_APP_NAME}
  template:
    metadata:
      labels:
        app: ${DL_APP_NAME}
    spec:
${NODE_SELECTOR_YAML}
      containers:
      - name: ${DL_APP_NAME}
        image: ${DL_REG_IMAGE}
        imagePullPolicy: Always
        resources:
          requests:
            cpu: "${K8S_CPU_REQ}"
            memory: "${K8S_MEMORY_REQ}"
          limits:
            cpu: "${K8S_CPU_LIMIT}"
            memory: "${K8S_MEMORY_LIMIT}"
        ports:
${CONTAINER_PORTS_YAML}
${READINESS_PROBE_YAML}
        env:
      dnsPolicy: ClusterFirst
      dnsConfig:
        options:
          - name: ndots
            value: "2"
      imagePullSecrets:
      - name: harbor-secret
EOF

  # If burst mode is enabled, generate a second deployment for spot replicas
  if [[ "${K8S_BURST_ENABLED:-false}" == "true" ]]; then
    local BURST_REPLICAS="${K8S_BURST_MIN_REPLICA:-1}"
    cat << EOF >> "$OUTPUT_FILE"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DL_APP_NAME}-burst
  namespace: ${K8S_NAMESPACE}
spec:
  replicas: ${BURST_REPLICAS}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: ${K8S_RU_SURGE}
      maxUnavailable: ${K8S_RU_UNAVAILABLE}
  selector:
    matchLabels:
      app: ${DL_APP_NAME}
      tier: burst
  template:
    metadata:
      labels:
        app: ${DL_APP_NAME}
        tier: burst
    spec:
${BURST_NODE_SELECTOR_YAML}
      containers:
      - name: ${DL_APP_NAME}
        image: ${DL_REG_IMAGE}
        imagePullPolicy: Always
        resources:
          requests:
            cpu: "${K8S_CPU_REQ}"
            memory: "${K8S_MEMORY_REQ}"
          limits:
            cpu: "${K8S_CPU_LIMIT}"
            memory: "${K8S_MEMORY_LIMIT}"
        ports:
${CONTAINER_PORTS_YAML}
${READINESS_PROBE_YAML}
        env:
      dnsPolicy: ClusterFirst
      dnsConfig:
        options:
          - name: ndots
            value: "2"
      imagePullSecrets:
      - name: harbor-secret
EOF
    echo "  ✅ Burst deployment (spot) generated"
  fi

  # Service selects by app label only — routes to both base and burst pods
  cat << EOF >> "$OUTPUT_FILE"
---
apiVersion: v1
kind: Service
metadata:
  name: ${DL_APP_NAME}
  namespace: ${K8S_NAMESPACE}
spec:
  selector:
    app: ${DL_APP_NAME}
  ports:
${SERVICE_PORTS_YAML}
EOF

  echo "Generated Kubernetes manifest saved to $OUTPUT_FILE"
}


function k8s_app_deployment {
  # check for k8s directory
  if [ ! -d "./ops/k8s" ]; then
    mkdir ./ops/k8s
  fi

  # clean house
  rm -rf ./ops/k8s/*

  k8s_app_mnf $dotenv ./ops/k8s/template.yml

  # if [[ "$branch" = "release/k8s-dev" ]]; then
  #   k8s_app_dev_deployment $dotenv ./ops/k8s/template.yml
  # fi
}

function k8s_app_env {
  # Add environment variables to a Kubernetes deployment manifest file.
  # Each env var references the ESO-managed secret "${DL_APP_NAME}-secrets".
  # DL_ENV_EXCLUDE filters out CI/K8s config vars that shouldn't be in the pod.
  local ENVFILE=$1
  local DEPLOYMENT_FILE=$2
  local NEW_DEPLOYMENT_FILE=$3
  local TEMPLATE="./ops/k8s/template.yml"

  generate_env_entry() {
      local key="$1"
      local secret_name="${DL_APP_NAME}-secrets"
      cat <<EOF
        - name: $key
          valueFrom:
            secretKeyRef:
              name: $secret_name
              key: $key
EOF
  }

  cp "$DEPLOYMENT_FILE" "$NEW_DEPLOYMENT_FILE"

  # Auto-exclude infra vars that should never be injected into pods
  local AUTO_EXCLUDE="K8S_NODE_SELECTOR K8S_BURST_ENABLED K8S_BURST_NODE_SELECTOR K8S_BURST_MIN_REPLICA K8S_BURST_MAX_REPLICA K8S_ING_STRATEGY"
  IFS=' ' read -r -a exclude <<< "$DL_ENV_EXCLUDE $AUTO_EXCLUDE"
  while IFS='=' read -r key value; do
      if [[ "$key" =~ ^#|^[[:space:]]*$ ]]; then
          continue
      fi
      if [[ " ${exclude[@]} " =~ " $key " ]]; then
          continue
      fi
      env_entry=$(generate_env_entry "$key")
      # Inject into all "env:" blocks (base + burst deployments)
      local tmpfile=$(mktemp)
      while IFS= read -r line; do
          echo "$line" >> "$tmpfile"
          if [[ "$line" =~ ^"        env:" ]]; then
              echo "$env_entry" >> "$tmpfile"
          fi
      done < "$NEW_DEPLOYMENT_FILE"
      mv "$tmpfile" "$NEW_DEPLOYMENT_FILE"
  done < "$ENVFILE"

  echo "✅ Environment variables added to: $NEW_DEPLOYMENT_FILE"
  rm $TEMPLATE
}

function k8s_ingress_app() {
  ENVFILE=$1
  OUTPUT_FILE=$2

  # Load the envfile
  if [[ -f "$ENVFILE" ]]; then
  source "$ENVFILE"
  else
  echo "Env file not found!"
  exit 1
  fi

  # Function to generate an Ingress manifest.
  # Accepts one argument: merge_type (empty for default, or "master"/"minion")
  generate_ingress() {
    local merge_type="$1"
    local ingress_name="$DL_APP_NAME"
    if [ -n "$merge_type" ]; then
      ingress_name="${DL_APP_NAME}-${merge_type}"
    fi

    local result="apiVersion: networking.k8s.io/v1\nkind: Ingress\nmetadata:\n"

    # Metadata: name and namespace
    result+="  name: $ingress_name\n"
    result+="  namespace: $K8S_NAMESPACE\n"

    # Build annotations block
    local annotations=""
    if [ -n "$merge_type" ]; then
      annotations+="    nginx.org/mergeable-ingress-type: \"$merge_type\"\n"
    fi

    # Common annotation for both master and others
    if [ -n "$K8S_CLIENT_BODY" ]; then
      annotations+="    nginx.org/client-max-body-size: \"$K8S_CLIENT_BODY\"\n"
    fi

    # For default and minion (full ingress), include additional annotations
    if [ -z "$merge_type" ] || [ "$merge_type" = "minion" ]; then
      if [ -n "$K8S_SSL_REDIRECT" ]; then
        annotations+="    nginx.org/ssl-redirect: \"$K8S_SSL_REDIRECT\"\n"
      fi
      if [ -n "$K8S_REWRITE_TARGET" ]; then
        annotations+="    nginx.org/rewrite-target: \"$K8S_REWRITE_TARGET\"\n"
      fi
      if [ -n "$K8S_ALLOWED_IPS" ]; then
        annotations+="    custom.nginx.org/allowed-ips: \"$K8S_ALLOWED_IPS\"\n"
      fi
      if [ -n "$K8S_EXTERNAL_DNS" ]; then
        annotations+="    external-dns.alpha.kubernetes.io/target: \"$K8S_EXTERNAL_DNS\"\n"
      fi
      # if [ -n "$K8S_REDIRECT_PATH" ] && [ -n "$K8S_REDIRECT_URL" ]; then
      #   annotations+="    nginx.org/location-snippets: |\n"
      #   IFS=',' read -r -a redirect_paths_array <<< "$K8S_REDIRECT_PATH"
      #   IFS=',' read -r -a redirect_urls_array <<< "$K8S_REDIRECT_URL"
      #   local len=${#redirect_paths_array[@]}
      #   for (( i=0; i<len; i++ )); do
      #     local path url
      #     path=$(echo "${redirect_paths_array[$i]}" | xargs)
      #     if [ -n "${redirect_urls_array[$i]}" ]; then
      #       url=$(echo "${redirect_urls_array[$i]}" | xargs)
      #     else
      #       url=$(echo "${redirect_urls_array[0]}" | xargs)
      #     fi
      #     annotations+="      if (\$request_uri ~* ^$path) {\n"
      #     annotations+="        return 302 $url;\n"
      #     annotations+="      }\n"
      #   done
      # fi
      if [ -n "$K8S_REDIRECT_PATH" ] && [ -n "$K8S_REDIRECT_URL" ]; then
        IFS=',' read -r -a redirect_paths_array <<< "$K8S_REDIRECT_PATH"
        IFS=',' read -r -a redirect_urls_array <<< "$K8S_REDIRECT_URL"

        local len=${#redirect_paths_array[@]}
        local server_snippets=""
        local location_snippets=""

        for (( i=0; i<len; i++ )); do
          local path url
          path=$(echo "${redirect_paths_array[$i]}" | xargs)

          if [ -n "${redirect_urls_array[$i]}" ]; then
            url=$(echo "${redirect_urls_array[$i]}" | xargs)
          else
            url=$(echo "${redirect_urls_array[0]}" | xargs)
          fi

          if [[ "$path" =~ ^https?:// ]]; then
            server_snippets+="      if (\$host = ${path#*//}) {\n"
            server_snippets+="        return 301 $url\$request_uri;\n"
            server_snippets+="      }\n"
          elif [[ "$path" =~ ^/ ]]; then
            location_snippets+="      if (\$request_uri ~* ^$path) {\n"
            location_snippets+="        return 302 $url;\n"
            location_snippets+="      }\n"
          fi
        done

        if [ -n "$server_snippets" ]; then
          annotations+="    nginx.org/server-snippets: |\n"
          annotations+="$server_snippets"
        fi

        if [ -n "$location_snippets" ]; then
          annotations+="    nginx.org/location-snippets: |\n"
          annotations+="$location_snippets"
        fi
      fi
    fi

    if [ -n "$annotations" ]; then
      result+="  annotations:\n"
      result+="$annotations"
    fi

    # Begin spec section
    result+="spec:\n"
    if [ -n "$K8S_ING_CLASS" ]; then
      result+="  ingressClassName: $K8S_ING_CLASS\n"
    fi

    # TLS block: only add if not a minion ingress
    if [ "$merge_type" != "minion" ] && [ -n "$K8S_TLS_HOSTS" ] && [ -n "$K8S_TLS_SECRETS" ]; then
      IFS=',' read -r -a tls_hosts_array <<< "$K8S_TLS_HOSTS"
      IFS=',' read -r -a tls_secrets_array <<< "$K8S_TLS_SECRETS"
      result+="  tls:\n"
      for i in "${!tls_hosts_array[@]}"; do
        local host secret
        host=$(echo "${tls_hosts_array[$i]}" | xargs)
        secret=$(echo "${tls_secrets_array[$i]}" | xargs)
        result+="    - hosts:\n"
        result+="        - $host\n"
        result+="      secretName: $secret\n"
      done
    fi

    # Rules block generation
    if [ "$merge_type" = "master" ]; then
      # For master, output a minimal rules block with only the host.
      local master_host=""
      if [ -n "$K8S_TLS_HOSTS" ]; then
        IFS=',' read -r -a tls_hosts_array <<< "$K8S_TLS_HOSTS"
        master_host=$(echo "${tls_hosts_array[0]}" | xargs)
      elif [ -n "$K8S_RULES" ]; then
        IFS=';' read -r -a rules_array <<< "$K8S_RULES"
        IFS=',' read -r master_host _ <<< "${rules_array[0]}"
        master_host=$(echo "$master_host" | xargs)
      fi
      if [ -n "$master_host" ]; then
        result+="  rules:\n"
        result+="  - host: $master_host\n"
      fi
    else
      # For minion and default, generate full rules with http paths.
      if [ -n "$K8S_RULES" ]; then
        result+="  rules:\n"
        IFS=';' read -r -a rules_array <<< "$K8S_RULES"
        declare -A host_rules
        for rule in "${rules_array[@]}"; do
          rule=$(echo "$rule" | xargs)
          IFS=',' read -r host path service port <<< "$rule"
          if [ -n "$host" ] && [ -n "$path" ] && [ -n "$service" ] && [ -n "$port" ]; then
            host_rules["$host"]+="$path,$service,$port;"
          fi
        done
        for host in "${!host_rules[@]}"; do
          result+="  - host: $host\n"
          result+="    http:\n"
          result+="      paths:\n"
          IFS=';' read -r -a paths_array <<< "${host_rules[$host]}"
          for entry in "${paths_array[@]}"; do
            if [ -n "$entry" ]; then
              IFS=',' read -r path service port <<< "$entry"
              result+="      - path: $path\n"
              result+="        pathType: Prefix\n"
              result+="        backend:\n"
              result+="          service:\n"
              result+="            name: $service\n"
              result+="            port:\n"
              result+="              number: $port\n"
            fi
          done
        done
      fi
    fi

    printf "$result"
  }

  # Main script logic
  final_output=""

  if [ "$K8S_ING_TYPE" = "app" ]; then
    final_output=$(generate_ingress "")
  elif [ -n "$K8S_ING_TYPE" ]; then
    IFS=',' read -r -a types_array <<< "$K8S_ING_TYPE"
    for type in "${types_array[@]}"; do
      type=$(echo "$type" | xargs)
      ingress_manifest=$(generate_ingress "$type")
      if [ -n "$final_output" ]; then
        final_output+="\n---\n"
      fi
      final_output+="$ingress_manifest"
    done
  else
    # K8S_ING_TYPE is empty - do nothing
    echo "K8S_ING_TYPE is empty, skipping ingress generation"
    return
  fi

  # Write the generated manifest to a file
  printf "$final_output" > $OUTPUT_FILE
  echo "Generated Ingress manifest saved to $OUTPUT_FILE"

}

function k8s_virtualserver_app() {
  ENVFILE=$1
  OUTPUT_FILE=$2

  # Load the envfile
  if [[ -f "$ENVFILE" ]]; then
  source "$ENVFILE"
  else
  echo "Env file not found!"
  exit 1
  fi

  # Function to generate a VirtualServer manifest
  # This creates the main VirtualServer resource (similar to master ingress)
  generate_virtualserver() {
    local result="apiVersion: k8s.nginx.org/v1\nkind: VirtualServer\nmetadata:\n"
    
    result+="  name: $DL_APP_NAME\n"
    result+="  namespace: $K8S_NAMESPACE\n"
    
    # Determine the host from TLS_HOSTS or RULES
    local vs_host=""
    if [ -n "$K8S_TLS_HOSTS" ]; then
      IFS=',' read -r -a tls_hosts_array <<< "$K8S_TLS_HOSTS"
      vs_host=$(echo "${tls_hosts_array[0]}" | xargs)
    elif [ -n "$K8S_RULES" ]; then
      IFS=';' read -r -a rules_array <<< "$K8S_RULES"
      IFS=',' read -r vs_host _ <<< "${rules_array[0]}"
      vs_host=$(echo "$vs_host" | xargs)
    fi
    
    result+="spec:\n"
    
    # Host configuration
    if [ -n "$vs_host" ]; then
      result+="  host: $vs_host\n"
    fi
    
    # TLS configuration
    if [ -n "$K8S_TLS_SECRETS" ]; then
      IFS=',' read -r -a tls_secrets_array <<< "$K8S_TLS_SECRETS"
      local tls_secret=$(echo "${tls_secrets_array[0]}" | xargs)
      result+="  tls:\n"
      result+="    secret: $tls_secret\n"
    fi
    
    # IngressClassName
    if [ -n "$K8S_ING_CLASS" ]; then
      result+="  ingressClassName: $K8S_ING_CLASS\n"
    fi
    
    # Routes - reference to VirtualServerRoute resources
    if [ -n "$K8S_RULES" ]; then
      result+="  routes:\n"
      IFS=';' read -r -a rules_array <<< "$K8S_RULES"
      
      # Create a unique list of paths for routes
      declare -A unique_paths
      for rule in "${rules_array[@]}"; do
        rule=$(echo "$rule" | xargs)
        IFS=',' read -r host path service port <<< "$rule"
        if [ -n "$path" ]; then
          path=$(echo "$path" | xargs)
          unique_paths["$path"]="1"
        fi
      done
      
      # Generate route references
      for path in "${!unique_paths[@]}"; do
        # Use DL_APP_NAME directly for the route reference
        # Each VirtualServerRoute is named after its app's DL_APP_NAME
        local route_name="$DL_APP_NAME"
        
        result+="  - path: $path\n"
        result+="    route: $route_name\n"
      done
    fi
    
    printf "$result"
  }

  # Function to generate VirtualServerRoute manifests
  # These are like minion ingresses - they define the actual backend services
  generate_virtualserver_routes() {
    local result=""
    
    if [ -z "$K8S_RULES" ]; then
      return
    fi
    
    IFS=';' read -r -a rules_array <<< "$K8S_RULES"
    
    # Group rules by path
    declare -A path_rules
    for rule in "${rules_array[@]}"; do
      rule=$(echo "$rule" | xargs)
      IFS=',' read -r host path service port <<< "$rule"
      if [ -n "$path" ] && [ -n "$service" ] && [ -n "$port" ]; then
        path=$(echo "$path" | xargs)
        service=$(echo "$service" | xargs)
        port=$(echo "$port" | xargs)
        path_rules["$path"]+="$service,$port;"
      else
        printf "%b" "${YELLOW}⚠ Warning: Skipping K8S_RULES entry with empty fields: host=$host path=$path service=$service port=$port${RESET}\n"
        printf "%b" "${YELLOW}  Check that DL_APP_NAME is defined before K8S_RULES in your env file${RESET}\n"
      fi
    done
    
    # Generate a VirtualServerRoute for each path
    local first=true
    for path in "${!path_rules[@]}"; do
      if [ "$first" = false ]; then
        result+="\n---\n"
      fi
      first=false
      
      # Use DL_APP_NAME directly for VirtualServerRoute resource name
      # The path is already specified in the spec, no need to append it to the name
      local route_name="$DL_APP_NAME"
      
      # Determine the host from TLS_HOSTS or RULES
      local vs_host=""
      if [ -n "$K8S_TLS_HOSTS" ]; then
        IFS=',' read -r -a tls_hosts_array <<< "$K8S_TLS_HOSTS"
        vs_host=$(echo "${tls_hosts_array[0]}" | xargs)
      elif [ -n "$K8S_RULES" ]; then
        IFS=';' read -r -a rules_array <<< "$K8S_RULES"
        IFS=',' read -r vs_host _ <<< "${rules_array[0]}"
        vs_host=$(echo "$vs_host" | xargs)
      fi
      
      result+="apiVersion: k8s.nginx.org/v1\n"
      result+="kind: VirtualServerRoute\n"
      result+="metadata:\n"
      result+="  name: $route_name\n"
      result+="  namespace: $K8S_NAMESPACE\n"
      result+="spec:\n"
      result+="  host: $vs_host\n"
      
      # IngressClassName
      if [ -n "$K8S_ING_CLASS" ]; then
        result+="  ingressClassName: $K8S_ING_CLASS\n"
      fi
      
      # Upstreams - define backend services
      result+="  upstreams:\n"
      IFS=';' read -r -a path_entries <<< "${path_rules[$path]}"
      local upstream_idx=0
      declare -A upstream_names
      
      for entry in "${path_entries[@]}"; do
        if [ -n "$entry" ]; then
          IFS=',' read -r service port <<< "$entry"
          local upstream_name="upstream-${upstream_idx}"
          upstream_names["$service,$port"]="$upstream_name"
          
          result+="  - name: $upstream_name\n"
          result+="    service: $service\n"
          result+="    port: $port\n"
          
          upstream_idx=$((upstream_idx + 1))
        fi
      done
      
      # Subroutes - define routing rules
      result+="  subroutes:\n"
      result+="  - path: $path\n"
      
      # Check for redirect first (redirect takes precedence)
      local has_redirect=false
      if [ -n "$K8S_REDIRECT_PATH" ] && [ -n "$K8S_REDIRECT_URL" ]; then
        IFS=',' read -r -a redirect_paths_array <<< "$K8S_REDIRECT_PATH"
        IFS=',' read -r -a redirect_urls_array <<< "$K8S_REDIRECT_URL"
        
        for (( i=0; i<${#redirect_paths_array[@]}; i++ )); do
          local redirect_path redirect_url
          redirect_path=$(echo "${redirect_paths_array[$i]}" | xargs)
          if [ -n "${redirect_urls_array[$i]}" ]; then
            redirect_url=$(echo "${redirect_urls_array[$i]}" | xargs)
          else
            redirect_url=$(echo "${redirect_urls_array[0]}" | xargs)
          fi
          
          # Check if redirect applies to this path
          if [[ "$redirect_path" =~ ^/ ]] && [[ "$path" == "$redirect_path"* ]]; then
            result+="    action:\n"
            result+="      redirect:\n"
            result+="        url: $redirect_url\n"
            result+="        code: 302\n"
            has_redirect=true
            break
          fi
        done
      fi
      
      # If no redirect, add pass action to upstream
      if [ "$has_redirect" = false ]; then
        if [ ${#upstream_names[@]} -eq 1 ]; then
          # Single upstream - direct pass
          for upstream_name in "${upstream_names[@]}"; do
            result+="    action:\n"
            result+="      pass: $upstream_name\n"
          done
        else
          # Multiple upstreams - use first one
          for upstream_name in "${upstream_names[@]}"; do
            result+="    action:\n"
            result+="      pass: $upstream_name\n"
            break
          done
        fi
      fi
    done
    
    printf "$result"
  }

  # Main script logic
  final_output=""

  # Determine what to generate based on K8S_ING_TYPE
  # Similar to mergeable ingress pattern:
  # - "master" = generate only VirtualServer (host definition)
  # - "minion" = generate only VirtualServerRoute (path/backend definition)
  # - "master,minion" or empty = generate both
  
  generate_vs=false
  generate_vsr=false
  
  if [ -z "$K8S_ING_TYPE" ] || [ "$K8S_ING_TYPE" = "app" ]; then
    # Default: generate both VirtualServer and VirtualServerRoute
    generate_vs=true
    generate_vsr=true
  else
    # Parse K8S_ING_TYPE to determine what to generate
    IFS=',' read -r -a types_array <<< "$K8S_ING_TYPE"
    for type in "${types_array[@]}"; do
      type=$(echo "$type" | xargs)
      if [ "$type" = "master" ]; then
        generate_vs=true
      elif [ "$type" = "minion" ]; then
        generate_vsr=true
      fi
    done
  fi
  
  # Generate VirtualServer if needed (like master ingress)
  if [ "$generate_vs" = true ]; then
    vs_manifest=$(generate_virtualserver)
    final_output="$vs_manifest"
  fi
  
  # Generate VirtualServerRoutes if needed (like minion ingress)
  if [ "$generate_vsr" = true ]; then
    vsr_manifests=$(generate_virtualserver_routes)
    if [ -n "$vsr_manifests" ]; then
      if [ -n "$final_output" ]; then
        final_output+="\n---\n"
      fi
      final_output+="$vsr_manifests"
    fi
  fi

  # Write the generated manifest to a file
  if [ -n "$final_output" ]; then
    printf "$final_output" > $OUTPUT_FILE
    if [ "$generate_vs" = true ] && [ "$generate_vsr" = true ]; then
      echo "Generated VirtualServer and VirtualServerRoute manifest saved to $OUTPUT_FILE"
    elif [ "$generate_vs" = true ]; then
      echo "Generated VirtualServer manifest saved to $OUTPUT_FILE"
    else
      echo "Generated VirtualServerRoute manifest saved to $OUTPUT_FILE"
    fi
  else
    echo "No manifest generated - check K8S_ING_TYPE configuration"
    return 1
  fi

  # Note: Auto-registration is handled in k8s_apply_manifest() after resources are created
  # Don't call auto_register_virtualserver_route() here - the VirtualServerRoute doesn't exist yet!

}

function auto_register_virtualserver_route() {
  echo ""
  printf "%b" "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
  printf "%b" "${BLUE}Auto-registering VirtualServerRoute with Master VirtualServer${RESET}\n"
  printf "%b" "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
  echo ""
  
  # Extract host from K8S_RULES
  local host=""
  if [ -n "$K8S_RULES" ]; then
    IFS=';' read -r -a rules_array <<< "$K8S_RULES"
    IFS=',' read -r host _ <<< "${rules_array[0]}"
    host=$(echo "$host" | xargs)
  fi
  
  if [ -z "$host" ]; then
    printf "%b" "${YELLOW}⚠ Warning: Cannot determine host from K8S_RULES${RESET}\n"
    printf "%b" "${YELLOW}   Skipping auto-registration${RESET}\n"
    return 1
  fi
  
  printf "%b" "${GREEN}→${RESET} Looking for VirtualServer with host: ${BLUE}$host${RESET}\n"
  
  # Find VirtualServer with matching host in the same namespace
  local vs_name=""
  vs_name=$(kubectl get virtualserver -n "$K8S_NAMESPACE" -o json 2>/dev/null | \
    jq -r ".items[] | select(.spec.host==\"$host\") | .metadata.name" | head -1)
  
  if [ -z "$vs_name" ]; then
    printf "%b" "${YELLOW}⚠ Warning: No VirtualServer found for host '$host' in namespace '$K8S_NAMESPACE'${RESET}\n"
    printf "%b" "${YELLOW}   Make sure the master app is deployed first${RESET}\n"
    printf "%b" "${YELLOW}   Skipping auto-registration${RESET}\n"
    return 1
  fi
  
  printf "%b" "${GREEN}✓${RESET} Found VirtualServer: ${BLUE}$vs_name${RESET}\n"
  
  # Extract paths and route names from K8S_RULES
  IFS=';' read -r -a rules_array <<< "$K8S_RULES"
  
  local routes_added=0
  for rule in "${rules_array[@]}"; do
    rule=$(echo "$rule" | xargs)
    IFS=',' read -r rule_host path service port <<< "$rule"
    
    if [ -z "$path" ]; then
      continue
    fi
    
    path=$(echo "$path" | xargs)
    
    # Use DL_APP_NAME directly for VirtualServerRoute resource name
    # This matches the logic in generate_virtualserver_routes()
    local route_name="$DL_APP_NAME"
    
    echo ""
    printf "%b" "${GREEN}→${RESET} Checking route: ${BLUE}$path${RESET} → ${BLUE}$route_name${RESET}\n"
    
    # Check if route already exists in VirtualServer
    local existing_route=""
    existing_route=$(kubectl get virtualserver "$vs_name" -n "$K8S_NAMESPACE" -o json 2>/dev/null | \
      jq -r ".spec.routes[]? | select(.path==\"$path\") | .route")
    
    if [ -n "$existing_route" ]; then
      if [ "$existing_route" = "$route_name" ]; then
        printf "%b" "${GREEN}✓${RESET} Route already registered correctly"
      else
        printf "%b" "${YELLOW}⚠${RESET} Route exists but points to different VirtualServerRoute: $existing_route"
        printf "%b" "${YELLOW}   Skipping to avoid overwriting${RESET}\n"
      fi
      continue
    fi
    
    # Add the route to VirtualServer
    printf "%b" "${GREEN}→${RESET} Adding route to VirtualServer..."
    
    # Patch with retry logic to handle concurrent updates
    local patch_result=1
    local patch_output=""
    for attempt in 1 2 3; do
      patch_output=$(kubectl patch virtualserver "$vs_name" -n "$K8S_NAMESPACE" \
        --type='json' \
        -p="[{
          \"op\": \"add\",
          \"path\": \"/spec/routes/-\",
          \"value\": {
            \"path\": \"$path\",
            \"route\": \"$route_name\"
          }
        }]" 2>&1)
      patch_result=$?
      
      if [ $patch_result -eq 0 ]; then
        printf "%b" "${GREEN}✓${RESET} Successfully registered route: ${BLUE}$path${RESET} → ${BLUE}$route_name${RESET}\n"
        routes_added=$((routes_added + 1))
        break
      else
        # Check if it's a resourceVersion error
        if echo "$patch_output" | grep -q "resourceVersion"; then
          if [ $attempt -lt 3 ]; then
            printf "%b" "${YELLOW}⚠${RESET} Resource conflict detected, retrying (attempt $attempt/3)..."
            sleep 1
          else
            printf "%b" "${YELLOW}⚠${RESET} Failed to register route after 3 attempts"
            printf "%b" "${YELLOW}   Error: Resource version conflict${RESET}\n"
            printf "%b" "${YELLOW}   The route will be registered on next deployment${RESET}\n"
          fi
        else
          printf "%b" "${RED}✗${RESET} Failed to register route: $patch_output"
          break
        fi
      fi
    done
  done
  
  echo ""
  if [ $routes_added -gt 0 ]; then
    printf "%b" "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "%b" "${GREEN}✓ Auto-registration complete! Added $routes_added route(s)${RESET}\n"
    printf "%b" "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    
    # Show the updated VirtualServer routes
    echo ""
    printf "%b" "${BLUE}Updated VirtualServer routes:${RESET}\n"
    kubectl get virtualserver "$vs_name" -n "$K8S_NAMESPACE" -o json 2>/dev/null | \
      jq -r '.spec.routes[] | "  • \(.path) → \(.route)"'
  else
    printf "%b" "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "%b" "${YELLOW}No routes were added (may already exist)${RESET}\n"
    printf "%b" "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
  fi
  echo ""
}

function validate_virtualserver_resources() {
  echo ""
  printf "%b" "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
  printf "%b" "${BLUE}Validating VirtualServer Resources${RESET}\n"
  printf "%b" "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
  echo ""
  
  local max_attempts=3
  local attempt=1
  local all_valid=false
  
  while [ $attempt -le $max_attempts ] && [ "$all_valid" = false ]; do
    if [ $attempt -gt 1 ]; then
      printf "%b" "${YELLOW}Validation attempt $attempt/$max_attempts...${RESET}\n"
      echo ""
    fi
    
    all_valid=true
    
    # Check VirtualServerRoute state
    printf "%b" "${GREEN}→${RESET} Checking VirtualServerRoute: ${BLUE}$DL_APP_NAME${RESET}\n"
    local vsr_state=""
    local vsr_message=""
    vsr_state=$(kubectl get virtualserverroute "$DL_APP_NAME" -n "$K8S_NAMESPACE" -o jsonpath='{.status.state}' 2>/dev/null)
    vsr_message=$(kubectl get virtualserverroute "$DL_APP_NAME" -n "$K8S_NAMESPACE" -o jsonpath='{.status.message}' 2>/dev/null)
    
    if [ "$vsr_state" = "Valid" ]; then
      printf "%b" "${GREEN}  ✓ State: Valid${RESET}\n"
    else
      printf "%b" "${RED}  ✗ State: $vsr_state${RESET}\n"
      if [ -n "$vsr_message" ]; then
        printf "%b" "${RED}  Error: $vsr_message${RESET}\n"
      fi
      all_valid=false
    fi
    
    # Check VirtualServer state and warnings
    # Dynamically find VirtualServer by extracting host from K8S_RULES
    echo ""
    local vs_host=""
    local vs_name=""
    
    if [ -n "$K8S_RULES" ]; then
      IFS=',' read -r vs_host _ _ _ <<< "$K8S_RULES"
    fi
    
    if [ -n "$vs_host" ]; then
      # Find VirtualServer by matching host
      vs_name=$(kubectl get virtualserver -n "$K8S_NAMESPACE" -o json 2>/dev/null | \
        jq -r --arg host "$vs_host" '.items[] | select(.spec.host == $host) | .metadata.name' 2>/dev/null | head -n 1)
    fi
    
    if [ -z "$vs_name" ]; then
      printf "%b" "${YELLOW}⚠${RESET} Could not find VirtualServer for host: ${YELLOW}$vs_host${RESET}\n"
      printf "%b" "${BLUE}  Skipping VirtualServer validation${RESET}\n"
    else
      printf "%b" "${GREEN}→${RESET} Checking VirtualServer: ${BLUE}$vs_name${RESET} (host: ${BLUE}$vs_host${RESET})"
      local vs_state=""
      local vs_message=""
      vs_state=$(kubectl get virtualserver "$vs_name" -n "$K8S_NAMESPACE" -o jsonpath='{.status.state}' 2>/dev/null)
      vs_message=$(kubectl get virtualserver "$vs_name" -n "$K8S_NAMESPACE" -o jsonpath='{.status.message}' 2>/dev/null)
      
      if [ "$vs_state" = "Valid" ]; then
        printf "%b" "${GREEN}  ✓ State: Valid${RESET}\n"
        # Check for warnings in message
        if echo "$vs_message" | grep -qi "warning"; then
          printf "%b" "${YELLOW}  ⚠ Message: $vs_message${RESET}\n"
          all_valid=false
        else
          printf "%b" "${GREEN}  ✓ Message: $vs_message${RESET}\n"
        fi
      else
        printf "%b" "${RED}  ✗ State: $vs_state${RESET}\n"
        if [ -n "$vs_message" ]; then
          printf "%b" "${RED}  Message: $vs_message${RESET}\n"
        fi
        all_valid=false
      fi
    fi
    
    echo ""
    
    # If not all valid and we have attempts left, try to fix
    if [ "$all_valid" = false ] && [ $attempt -lt $max_attempts ]; then
      printf "%b" "${YELLOW}⚠ Resources are not fully valid, attempting to fix...${RESET}\n"
      echo ""
      
      # Delete and reapply VirtualServerRoute if it's not Valid
      if [ "$vsr_state" != "Valid" ]; then
        printf "%b" "${YELLOW}→${RESET} Deleting VirtualServerRoute ${BLUE}$DL_APP_NAME${RESET} (state: ${YELLOW}$vsr_state${RESET})"
        kubectl delete virtualserverroute "$DL_APP_NAME" -n "$K8S_NAMESPACE" --ignore-not-found
        
        printf "%b" "${YELLOW}→${RESET} Waiting for cleanup..."
        sleep 3
        
        printf "%b" "${YELLOW}→${RESET} Reapplying VirtualServerRoute from ${BLUE}./ops/k8s/ing.yml${RESET}\n"
        kubectl apply --server-side --force-conflicts -f ./ops/k8s/ing.yml
        
        printf "%b" "${YELLOW}→${RESET} Waiting for resources to settle..."
        sleep 5
      else
        printf "%b" "${BLUE}→${RESET} VirtualServerRoute is Valid, issue is with VirtualServer"
        printf "%b" "${BLUE}→${RESET} Waiting for VirtualServer to update..."
        sleep 5
      fi
      
      echo ""
    fi
    
    attempt=$((attempt + 1))
  done
  
  # Final status
  echo ""
  if [ "$all_valid" = true ]; then
    printf "%b" "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "%b" "${GREEN}✓ All VirtualServer resources are Valid!${RESET}\n"
    printf "%b" "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    echo ""
    return 0
  else
    printf "%b" "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "%b" "${RED}✗ Resources validation failed after $max_attempts attempts${RESET}\n"
    printf "%b" "${RED}  Manual intervention may be required${RESET}\n"
    printf "%b" "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    echo ""
    return 1
  fi
}

function k8s_apply_virtualserver() {
  # Apply VirtualServer/VirtualServerRoute manifests with auto-registration
  local MANIFEST=$1
  
  if [ -z "$MANIFEST" ]; then
    printf "%b" "${RED}Error: No manifest file specified${RESET}\n"
    return 1
  fi
  
  if [ ! -f "$MANIFEST" ]; then
    printf "%b" "${RED}Error: Manifest file not found: $MANIFEST${RESET}\n"
    return 1
  fi
  
  printf "%b" "${BLUE}Applying VirtualServer/VirtualServerRoute manifests...${RESET}\n"
  
  # Apply the manifests
  kubectl apply -f "$MANIFEST"
  
  local apply_result=$?
  
  if [ $apply_result -eq 0 ]; then
    printf "%b" "${GREEN}✓ Manifests applied successfully${RESET}\n"
    
    # If this is a minion deployment with virtualserver strategy, auto-register
    if [ "$K8S_ING_STRATEGY" = "virtualserver" ] && [ "$K8S_ING_TYPE" = "minion" ]; then
      # Wait a moment for resources to be created
      sleep 2
      auto_register_virtualserver_route
    fi
  else
    printf "%b" "${RED}✗ Failed to apply manifests${RESET}\n"
    return 1
  fi
}

function k8s_hpa_gen {
  # script to generate k8s manifest file from a template file
  # Usage: ./app.sh .env template.yml

  ENVFILE=$1
  OUTPUT_FILE=$2

  # Load the envfile
  if [[ -f "$ENVFILE" ]]; then
    source "$ENVFILE"
  else
    echo "Env file not found!"
    exit 1
  fi

  # When burst is enabled, HPA targets the burst deployment (spot replicas)
  # The base deployment stays at fixed K8S_MIN_REPLICA count
  if [[ "${K8S_BURST_ENABLED:-false}" == "true" ]]; then
    local HPA_TARGET="${DL_APP_NAME}-burst"
    local HPA_NAME="${DL_APP_NAME}-burst"
    local HPA_MIN="${K8S_BURST_MIN_REPLICA:-1}"
    local HPA_MAX="${K8S_BURST_MAX_REPLICA:-${K8S_MAX_REPLICA}}"
  else
    local HPA_TARGET="${DL_APP_NAME}"
    local HPA_NAME="${DL_APP_NAME}"
    local HPA_MIN="${K8S_MIN_REPLICA}"
    local HPA_MAX="${K8S_MAX_REPLICA}"
  fi

  cat > "$OUTPUT_FILE" << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${HPA_NAME}
  namespace: ${K8S_NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${HPA_TARGET}
  minReplicas: ${HPA_MIN}
  maxReplicas: ${HPA_MAX}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: ${K8S_CPU_AVERAGE}
EOF

  echo "Autoscaling config successfully generated @ $OUTPUT_FILE"
}

function k8s_autoscaling {
  k8s_hpa_gen $dotenv ./ops/k8s/hpa.yml
}

function k8s_external_secret {
  # Generate an ExternalSecret manifest for ESO.
  # Only creates the file — does NOT apply it.
  local OUTPUT_FILE="${1:-./ops/k8s/external-secret.yml}"
  local SECRET_NAME="${DL_APP_NAME}-secrets"
  # Try VAULT_SECRET_KEY first, then fall back to VAULT_SECRET_BASE_PATH (set by CI workflow)
  local VAULT_PATH="${VAULT_SECRET_KEY:-${VAULT_SECRET_BASE_PATH:-}}"

  if [ -z "$VAULT_PATH" ]; then
    printf "%b" "\033[1;33m! VAULT_SECRET_KEY/VAULT_SECRET_BASE_PATH is empty — skipping ExternalSecret generation\033[0m\n"
    return 0
  fi

  printf "%b" "\033[1;34m→ Generating ExternalSecret for $DL_APP_NAME (Vault: kv/$VAULT_PATH)\033[0m\n"

  cat > "$OUTPUT_FILE" <<EOF
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ${DL_APP_NAME}
  namespace: ${K8S_NAMESPACE}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-kv
    kind: ClusterSecretStore
  target:
    name: ${SECRET_NAME}
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: ${VAULT_PATH}
EOF

  printf "%b" "\033[1;32m✓ ExternalSecret manifest generated: $OUTPUT_FILE\033[0m\n"
}

function k8s_eso_sync {
  # Force ESO re-sync and verify after apply.
  local SECRET_NAME="${DL_APP_NAME}-secrets"

  printf "%b" "\033[1;34m→ Forcing ESO re-sync...\033[0m\n"
  kubectl annotate externalsecret "${DL_APP_NAME}" \
    -n "${K8S_NAMESPACE}" \
    force-sync="$(date +%s)" \
    --overwrite 2>/dev/null || true

  sleep 3

  local STATUS
  STATUS=$(kubectl get externalsecret "${DL_APP_NAME}" -n "${K8S_NAMESPACE}" -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null)
  if [ "$STATUS" = "SecretSynced" ]; then
    printf "%b" "\033[1;32m✓ Secret synced successfully: $SECRET_NAME\033[0m\n"
  else
    printf "%b" "\033[1;33m! Sync status: $STATUS (may still be syncing)\033[0m\n"
  fi
}

function k8s_apply_manifest {
  local MANIFEST=$1
  
  # For VirtualServer strategy, ALWAYS delete VirtualServerRoute before applying
  # This prevents server-side apply from merging with ANY stale configurations
  # Server-side apply does not reliably replace structural changes (e.g. redirect→pass)
  if [ "$K8S_ING_STRATEGY" = "virtualserver" ] && [ -n "$DL_APP_NAME" ] && [ -n "$K8S_NAMESPACE" ]; then
    # Check if VirtualServerRoute exists
    if kubectl get virtualserverroute "$DL_APP_NAME" -n "$K8S_NAMESPACE" >/dev/null 2>&1; then
      printf "%b" "${BLUE}→${RESET} Found existing VirtualServerRoute '$DL_APP_NAME'"
      printf "%b" "${BLUE}  Deleting to ensure clean deployment (prevents merge issues)...${RESET}\n"
      kubectl delete virtualserverroute "$DL_APP_NAME" -n "$K8S_NAMESPACE"
      sleep 2
    fi
  fi
  
  # Apply the manifests
  # Use server-side apply for VirtualServer resources to avoid resourceVersion conflicts
  if [ "$K8S_ING_STRATEGY" = "virtualserver" ]; then
    kubectl apply --server-side --force-conflicts -f $MANIFEST
  else
    kubectl apply -f $MANIFEST
  fi
  local apply_result=$?
  
  # If using VirtualServer strategy with minion-only type, auto-register routes
  # Only trigger for pure minion deployments (not "master,minion")
  if [ $apply_result -eq 0 ] && [ "$K8S_ING_STRATEGY" = "virtualserver" ]; then
    # Check if this is minion-only (not master,minion or other combinations)
    local is_minion_only=false
    local has_master=false
    local has_minion=false
    
    if [ -n "$K8S_ING_TYPE" ]; then
      IFS=',' read -r -a types_array <<< "$K8S_ING_TYPE"
      for type in "${types_array[@]}"; do
        type=$(echo "$type" | xargs)
        if [ "$type" = "master" ]; then
          has_master=true
        elif [ "$type" = "minion" ]; then
          has_minion=true
        fi
      done
    fi
    
    # Only auto-register if minion without master
    if [ "$has_minion" = true ] && [ "$has_master" = false ]; then
      # Wait for resources to be fully created and settle
      printf "%b" "${BLUE}Waiting for VirtualServerRoute to be created...${RESET}\n"
      sleep 3
      auto_register_virtualserver_route
      
      # Validate resources after auto-registration
      validate_virtualserver_resources
      local validation_result=$?
      
      # Update apply_result if validation failed
      if [ $validation_result -ne 0 ]; then
        apply_result=1
      fi
    fi
  fi
  
  return $apply_result
}

function k8s_delete_manifests {
  local MANIFEST=$1
  kubectl --context $K8S_CONTEXT delete -f $MANIFEST
}

function stack() {
  if [ "$(hostname)" == "bams" ]; then
    bash /Users/bamsd/dev/🚀/sh/@.sh "$1"
  fi
}
function dev() {
  if [[ "$DL_APP_STACK" == "vitejs" ]]; then
    stack 2
  elif [[ "$DL_APP_STACK" == "nextjs" ]]; then
    stack 3
  elif [[ "$DL_APP_STACK" == "nodejs" ]]; then
    stack 4
  elif [[ "$DL_APP_STACK" == "nestjs" ]]; then
    stack 5
  elif [[ "$DL_APP_STACK" == "dotnet" ]]; then
    stack 11
  elif [[ "$DL_APP_STACK" == "bunjs" ]]; then
    stack 12
  fi
}

#---------------------------------------#
# CI/CD                                 #
#---------------------------------------#
function deploy_ci_cd {
  make
  gitea_env repo
  gitea_workflow_secret
  mikrotik_dns
  create_route53_record
}

# set vault secrets on github
function gh_set_vault_secrets {
  printf "%b" "${BLUE}Setting VAULT_URL and VAULT_TOKEN as GitHub secrets...${RESET}\n"

  if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
    printf "%b" "${RED}Error: VAULT_ADDR and/or VAULT_TOKEN are not set in the environment.${RESET}\n"
    printf "%b" "${YELLOW}Please ensure they are defined in ./${APP_SRC_DIR}/.env${RESET}\n"
    return 1
  fi

  if [ -z "$DL_GH_OWNER_REPO" ]; then
    printf "%b" "${RED}Error: DL_GH_OWNER_REPO is not set in the environment.${RESET}\n"
    printf "%b" "${YELLOW}Please ensure it is defined in ./${APP_SRC_DIR}/.env${RESET}\n"
    return 1
  fi

  # Ensure gh CLI is available and authenticated and repo is accessible
  if ! command -v gh >/dev/null 2>&1; then
    printf "%b" "${RED}Error: GitHub CLI 'gh' not found in PATH.${RESET}\n"
    printf "%b" "${YELLOW}Install GitHub CLI and authenticate (gh auth login) or set a valid GITHUB_TOKEN in the environment.${RESET}\n"
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    printf "%b" "${RED}Error: gh CLI is not authenticated or has no valid token.${RESET}\n"
    printf "%b" "${YELLOW}Run 'gh auth login' or set GITHUB_TOKEN/GH_TOKEN with a token that has repo:public_repo or repo scope.${RESET}\n"
    return 1
  fi

  # Verify repository exists and is reachable
  if ! gh repo view "$DL_GH_OWNER_REPO" >/dev/null 2>&1; then
    printf "%b" "${RED}Error: repository '$DL_GH_OWNER_REPO' not found or you do not have access.${RESET}\n"
    printf "%b" "${YELLOW}Check that DL_GH_OWNER_REPO is correct and that your token/user has access to the repository.${RESET}\n"
    return 1
  fi

  # Set VAULT_URL secret
  printf "%b" "${GREEN}Setting VAULT_URL secret...${RESET}\n"
  if echo "$VAULT_ADDR" | gh secret set VAULT_URL --repo "$DL_GH_OWNER_REPO"; then
    printf "%b" "${GREEN}✅ VAULT_URL secret set successfully.${RESET}\n"
  else
    printf "%b" "${RED}❌ Failed to set VAULT_URL secret.${RESET}\n"
    return 1
  fi

  # Set VAULT_TOKEN secret
  printf "%b" "${GREEN}Setting VAULT_TOKEN secret...${RESET}\n"
  if echo "$VAULT_TOKEN" | gh secret set VAULT_TOKEN --repo "$DL_GH_OWNER_REPO"; then
    printf "%b" "${GREEN}✅ VAULT_TOKEN secret set successfully.${RESET}\n"
  else
    printf "%b" "${RED}❌ Failed to set VAULT_TOKEN secret.${RESET}\n"
    return 1
  fi

  printf "%b" "${BLUE}🎉 GitHub Vault secrets setup complete!${RESET}\n"
}

#---------------------------------------#
# deploy to k8s                         #
#---------------------------------------#
function k8s_create_manifests {
  # make
  # dev
  rm -rf ./ops/k8s/*
  k8s_app_deployment
  k8s_app_env $dotenv ./ops/k8s/template.yml ./ops/k8s/app.yml
  
  # Choose ingress strategy based on K8S_ING_STRATEGY
  if [ "$K8S_ING_STRATEGY" = "virtualserver" ]; then
    k8s_virtualserver_app $dotenv ./ops/k8s/ing.yml
  else
    # Default to mergeable ingress
    k8s_ingress_app $dotenv ./ops/k8s/ing.yml
  fi
  
  k8s_autoscaling
  k8s_external_secret ./ops/k8s/external-secret.yml
}

function k8s_full_deploy {
  commit_status
  set_kube_context $K8S_CONTEXT $K8S_NAMESPACE
  docker_build
  docker_push yes
  k8s_create_manifests
  k8s_apply_manifest ./ops/k8s/
  k8s_eso_sync
}

function k8s_mini_deploy {
  commit_status
  set_kube_context $K8S_CONTEXT $K8S_NAMESPACE
  k8s_create_manifests
  k8s_apply_manifest ./ops/k8s/
  k8s_eso_sync
}

function k8s_minus_ingress {
  commit_status
  set_kube_context $K8S_CONTEXT $K8S_NAMESPACE
  docker_build
  docker_push yes
  k8s_app_deployment
  k8s_app_env $dotenv ./ops/k8s/template.yml ./ops/k8s/app.yml
  k8s_autoscaling
  k8s_external_secret ./ops/k8s/external-secret.yml
  k8s_apply_manifest ./ops/k8s/
  k8s_eso_sync
}

function k8s_create_manifests_only {
  k8s_app_deployment
  k8s_app_env $dotenv ./ops/k8s/template.yml ./ops/k8s/app.yml
  k8s_autoscaling
  # Choose ingress strategy based on K8S_ING_STRATEGY
  if [ "$K8S_ING_STRATEGY" = "virtualserver" ]; then
    k8s_virtualserver_app $dotenv ./ops/k8s/ing.yml
  else
    # Default to mergeable ingress
    k8s_ingress_app $dotenv ./ops/k8s/ing.yml
  fi
}

# Define available actions
declare -A actions=(
  [0]="nginx_config"
  [1]="git_repo_create"
  [2]="git_commit"
  [3]="git_repo_push"
  [4]="git_repo_scan"
  [5]="git_repo_rename"
  [6]="gh_repo_create"
  [7]="gh_repo_rename"
  [8]="gh_repo_check"
  [9]="gh_repo_view"
  [10]="gitea_env"
  [11]="gitea_workflow_secret"
  [12]="docker_build"
  [13]="docker_push yes"
  [14]="create_route53_record"
  [15]="create_app_dir"
  [16]="clone_app_repo"
  [17]="copy_app_env"
  [18]="create_nginx_vhost"
  [19]="ga_deploy_app"
  [20]="k8s_app_deployment \$dotenv ./ops/k8s/template.yml"
  [21]="k8s_app_env \$dotenv ./ops/k8s/template.yml ./ops/k8s/app.yml"
  [22]="k8s_external_secret ./ops/k8s/external-secret.yml"
  [23]="k8s_eso_sync"
  [24]="k8s_apply_manifest ./ops/k8s/"
  [25]="delete_pod \$K8S_NAMESPACE \$DL_APP_NAME"
  [26]="mikrotik_dns"
  [27]="deploy_dclm_ec2"
  [28]="deploy_ci_cd"
  [29]="k8s_mini_deploy"
  [30]="k8s_full_deploy"
  [31]="k8s_minus_ingress"
  [32]="k8s_create_manifests"
  [33]="k8s_delete_manifests ./ops/k8s/"
  [34]="gh_set_vault_secrets"
  [35]="k8s_create_manifests_only"
  [00]="dotenvfile"
)

declare -A descriptions=(
  [0]="Nginx config"
  [1]="Git: Create repo"
  [2]="Git: Commit repo"
  [3]="Git: Push repo"
  [4]="Git: Scan repo"
  [5]="Git: Rename repo"
  [6]="GitHub: Create repo"
  [7]="GitHub: Rename repo"
  [8]="GitHub: Check repo"
  [9]="GitHub: View repo"
  [10]="Gitea: Create repo env for CI/CD"
  [11]="Gitea: Generate workflow for CI/CD"
  [12]="Docker: Build image"
  [13]="Docker: Push image"
  [14]="DNS: Create route53 record"
  [15]="APP: Create directory"
  [16]="APP: Clone app repo"
  [17]="APP: Copy app env"
  [18]="Nginx: Create vhost"
  [19]="Deploy app to server"
  [20]="K8S: Generate app manifest"
  [21]="K8S: Generate app env"
  [22]="K8S: Generate app secret"
  [23]="K8S: Seal secret with Kubeseal"
  [24]="K8S: Apply manifest"
  [25]="K8S: Delete pod"
  [26]="DNS: Create record on Mikrotik"
  [27]="Deploy app to EC2 instance"
  [28]="CI/CD: Deploy"
  [29]="K8S: Mini Deploy"
  [30]="K8S: Full Deploy"
  [31]="K8S: No Ingress"
  [32]="K8S: Create deployment manifests"
  [33]="K8S: Delete deployment manifests"
  [34]="GitHub: Set Vault secret"
  [35]="K8S: Generate full deployment manifests only"
  [00]="Generate .env file"
)

# Check if a choice was provided as a command line argument
if [ $# -eq 0 ]; then
  # Display menu
  for key in $(printf '%s\n' "${!descriptions[@]}" | sort -n); do
    printf "%02d) %s\n" "$key" "${descriptions[$key]}"
  done
  echo "----------------------------------"
  read -p $'\nSelect action to perform [0-33]: ' choice
else
  choice="$1"
fi

# Execute the selected action
if [[ -n "${actions[$choice]}" ]]; then
  eval "${actions[$choice]}"
else
  echo "Invalid selection: $choice"
  exit 1
fi
