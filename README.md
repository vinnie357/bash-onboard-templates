# workspace-onboard-bash-templates
bash startup scripts for development boxes

# example template
    data "http" "template_vscode_dev" {
        url = "https://raw.githubusercontent.com/vinnie357/workspace-onboard-bash-templates/master/vscode-extension-dev/f5-fast-ext/onboard.sh"
    }
    data "template_file" "vm_onboard_vscode_dev" {
        
        template = "${data.http.template_vscode_dev.body}"
        vars = {
            repositories       	  = "https://github.com/vinnie357/bigip-bash-onboard-templates.git,https://github.com/vinnie357/workspace-onboard-bash-templates.git"
            user            	  = "zadmin"
        }
    }
    resource "local_file" "onboard_file_vscode_dev" {
        content     = "${data.template_file.vm_onboard_vscode_dev.rendered}"
        filename    = "${path.module}/onboard-vscode-dev-debug-bash.sh"
    }