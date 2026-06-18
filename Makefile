.PHONY: format

clean:
	find . -type d -name ".terragrunt-cache" -prune -exec rm -rf {} \;
	find . -type f -name ".terraform.lock.hcl" -prune -exec rm -rf {} \;

format:
	find . -type f -name '*.hcl' -exec terragrunt hcl fmt {} +
	terraform fmt -recursive terraform/
