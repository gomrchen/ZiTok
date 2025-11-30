package notes

import (
	"github.com/yxrxy/videoHub/app/notes/controllers/rpc"
	"github.com/yxrxy/videoHub/app/notes/domain/repository"
	"github.com/yxrxy/videoHub/app/notes/domain/service"
	"github.com/yxrxy/videoHub/app/notes/infrastructure/mysql"
	"github.com/yxrxy/videoHub/app/notes/usecase"
	"github.com/yxrxy/videoHub/config"
	gormmysql "gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// Injector 笔记模块依赖注入器
type Injector struct {
	db *gorm.DB
}

// NewInjector 创建笔记模块依赖注入器
func NewInjector(db *gorm.DB) *Injector {
	return &Injector{db: db}
}

// InjectRepositories 注入仓库依赖
func (i *Injector) InjectRepositories() (
	repository.NoteRepository,
	repository.NoteLikeRepository,
	repository.NoteCommentRepository,
	repository.NoteFavoriteRepository,
) {
	noteRepo := mysql.NewNoteRepository(i.db)
	noteLikeRepo := mysql.NewNoteLikeRepository(i.db)
	noteCommentRepo := mysql.NewNoteCommentRepository(i.db)
	noteFavoriteRepo := mysql.NewNoteFavoriteRepository(i.db)

	return noteRepo, noteLikeRepo, noteCommentRepo, noteFavoriteRepo
}

// InjectServices 注入服务依赖
func (i *Injector) InjectServices() service.NoteService {
	noteRepo, _, _, _ := i.InjectRepositories()
	noteService := service.NewNoteService(noteRepo)

	return noteService
}

// InjectUsecases 注入用例依赖
func (i *Injector) InjectUsecases() *usecase.NoteUsecase {
	noteService := i.InjectServices()
	noteRepo, noteLikeRepo, noteCommentRepo, noteFavoriteRepo := i.InjectRepositories()

	noteUsecase := usecase.NewNoteUsecase(
		noteService,
		noteRepo,
		noteLikeRepo,
		noteCommentRepo,
		noteFavoriteRepo,
	)

	return noteUsecase
}

// InjectHandlers 注入处理器依赖
func (i *Injector) InjectHandlers() *rpc.NoteServiceHandler {
	noteUsecase := i.InjectUsecases()
	noteHandler := rpc.NewNoteServiceHandler(noteUsecase)

	return noteHandler
}

// InjectUserHandler 全局注入处理器依赖（用于main函数）
func InjectHandlers() *rpc.NoteServiceHandler {
    // 初始化数据库
    dsn := config.GetDSN()
    db, err := gorm.Open(gormmysql.Open(dsn), &gorm.Config{})
    if err != nil {
        panic(err)
    }

    // 自动迁移笔记相关表结构
    if err := mysql.AutoMigrate(db); err != nil {
        panic(err)
    }

    // 创建注入器并返回处理器
    injector := NewInjector(db)
    return injector.InjectHandlers()
}
