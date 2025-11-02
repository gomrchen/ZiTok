GREEN_COLOR_START:=\033[32m
RED_COLOR_START:=\033[31m
COLOR_END:=\033[0m

# 一键部署
.PHONY: deploy
deploy:
	@echo "$(RED_COLOR_START) deploy may last a long time$(COLOR_END)"
	@sh ./scripts/deploy.sh create

# 配置文件有改动的话可以使用这个.
.PHONY: apply
apply:
	@sh ./scripts/deploy.sh apply

# 删除所有环境, 不包括刚刚构建的镜像. 请自行删除
.PHONY: down
down:
	@sh ./scripts/deploy.sh delete

# 只有当你需要把数据挂载到本地时, 你才需要这条命令, 你还需要更改任何 pv 配置中的 nodeAffinity ,而且他需要运行在 make deploy 之前
# 相关测试并不完善, 不建议使用.
.PHONY: dir-create
dir-create:
	@sudo sh ./scripts/dir.sh create

.PHONY: dir-delete
dir-delete:
	@sudo sh ./scripts/dir.sh delete

# 格式化代码，我们使用 gofumpt，是 fmt 的严格超集
.PHONY: fmt
fmt:
	gofumpt -l -w .

# 优化 import 顺序结构
.PHONY: import
import:
	goimports -w -local github.com/mutezebra .

# 检查可能的错误
.PHONY: vet
vet:
	go vet ./...

# 代码格式校验
.PHONY: lint
lint:
	golangci-lint run --config=.golangci.yml --tests --allow-parallel-runners --sort-results --show-stats --print-resources-usage

# 检查依赖漏洞
.PHONY: vulncheck
vulncheck:
	govulncheck ./...

.PHONY: tidy
tidy:
	go mod tidy

# 一键修正规范并执行代码检查
.PHONY: verify
verify: vet fmt import lint vulncheck tidy
