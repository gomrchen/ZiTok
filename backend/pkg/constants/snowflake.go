package constants

import "time"

var (
	epochTime, _ = time.Parse("2006-01-02 15:04:05", epochStr)
	Epoch        = epochTime.UnixMilli()
)

const (
	epochStr          = "2024-03-19 00:00:00"
	TimestampBits     = uint(41)                                       // 时间戳占用位数
	DataCenterIDBits  = uint(2)                                        // 数据中心id所占位数
	WorkerIDBits      = uint(7)                                        // 机器id所占位数
	SequenceBits      = uint(12)                                       // 序列所占的位数
	TimestampMax      = int64(-1 ^ (-1 << TimestampBits))              // 时间戳最大值
	DataCenterIDMax   = int64(-1 ^ (-1 << DataCenterIDBits))           // 支持的最大数据中心id数量
	WorkerIDMax       = int64(-1 ^ (-1 << WorkerIDBits))               // 支持的最大机器id数量
	SequenceMask      = int64(-1 ^ (-1 << SequenceBits))               // 支持的最大序列id数量
	WorkerIDShift     = SequenceBits                                   // 机器id左移位数
	DataCenterIDShift = SequenceBits + WorkerIDBits                    // 数据中心id左移位数
	TimestampShift    = SequenceBits + WorkerIDBits + DataCenterIDBits // 时间戳左移位数
)
