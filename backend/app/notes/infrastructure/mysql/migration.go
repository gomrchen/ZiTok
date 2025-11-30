package mysql

import (
	"fmt"

	"github.com/yxrxy/videoHub/app/notes/domain/model"
	"gorm.io/gorm"
)

// AutoMigrate 自动迁移数据库表
func AutoMigrate(db *gorm.DB) error {
	fmt.Println("开始迁移笔记模块数据库表...")

	// 自动迁移表结构
	err := db.AutoMigrate(
		&model.Note{},
		&model.NoteLike{},
		&model.NoteComment{},
		&model.NoteFavorite{},
	)

	if err != nil {
		return fmt.Errorf("笔记模块数据库迁移失败: %w", err)
	}

	fmt.Println("笔记模块数据库表迁移完成")
	return nil
}
