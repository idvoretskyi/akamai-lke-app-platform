VALUES_DIR ?= .values
MANIFESTS  := $(VALUES_DIR)/env/manifests
SCRIPTS    := ../../tofu/scripts

# The only paths this example may write to inside the values repo. Anything
# under an apl-* directory is owned by the App Platform operator.
NS_DEST    := $(MANIFESTS)/namespaces/hello/
GLOBAL_DEST := $(MANIFESTS)/global/clusterrole/
CR_FILE    := hello-readonly.yaml

.PHONY: clone sync push status clean guard

## Clone (or pull) the App Platform values repo into .values/.
clone:
	VALUES_DIR=$(VALUES_DIR) $(SCRIPTS)/apl-values-clone.sh

## Refuse to touch operator-owned apl-* paths.
guard:
	@for p in "$(NS_DEST)" "$(GLOBAL_DEST)"; do \
	  case "$$p" in *apl-*) echo "Refusing to write to operator-owned path: $$p" >&2; exit 1;; esac; \
	done
	@test -d "$(VALUES_DIR)/.git" || { echo "No values repo in $(VALUES_DIR); run 'make clone' first." >&2; exit 1; }

## Copy this example's manifests into the values repo (hello/ and one ClusterRole only).
sync: guard
	mkdir -p "$(NS_DEST)" "$(GLOBAL_DEST)"
	rsync -a --delete manifests/namespaces/hello/ "$(NS_DEST)"
	rsync -a manifests/global/clusterrole/$(CR_FILE) "$(GLOBAL_DEST)$(CR_FILE)"
	git -C "$(VALUES_DIR)" status --short env/manifests

## Commit (signed off) and push; ArgoCD reconciles within a few minutes.
push: guard
	git -C "$(VALUES_DIR)" add env/manifests/namespaces/hello env/manifests/global/clusterrole/$(CR_FILE)
	git -C "$(VALUES_DIR)" commit -s -m "hello: sync manifests"
	git -C "$(VALUES_DIR)" push

## Show the ArgoCD Applications and workloads for this example.
status:
	kubectl get applications -A | grep -E 'NAME|hello|global' || true
	kubectl get all -n hello

## Remove this example from the values repo, commit and push (ArgoCD prunes).
clean: guard
	rm -rf "$(NS_DEST)"
	rm -f "$(GLOBAL_DEST)$(CR_FILE)"
	git -C "$(VALUES_DIR)" add -A env/manifests/namespaces/hello env/manifests/global/clusterrole
	git -C "$(VALUES_DIR)" commit -s -m "hello: remove example"
	git -C "$(VALUES_DIR)" push
