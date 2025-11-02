package tests

import (
	"bytes"
	"encoding/gob"
	"encoding/json"
	"strconv"
	"testing"

	"google.golang.org/protobuf/proto"
)

type MMessage struct {
	MsgType   int8 `json:"msg_type"`
	HaveRead  bool
	PageSize  int8   `json:"page_size"`
	PageNum   int32  `json:"page_num"`
	Content   string `json:"content"`
	TimeStart string `json:"time_start"`
	TimeEnd   string `json:"time_end"`
	GroupID   int64  `json:"group_id"`
	From      int64
	To        int64
	CreateAt  int64
}

// 生成指定长度的内容
func generateContent(length int) string {
	return string(bytes.Repeat([]byte("a"), length))
}

// 测试不同消息大小的 json 序列化
func benchmarkJsonMarshalMessage(b *testing.B, contentLength int) {
	msg := &MMessage{
		MsgType:   1,
		HaveRead:  true,
		PageSize:  10,
		PageNum:   1,
		Content:   generateContent(contentLength),
		TimeStart: "2023-01-01 00:00:00",
		TimeEnd:   "2023-01-01 01:00:00",
		GroupID:   12345,
		From:      67890,
		To:        12345,
		CreateAt:  1672531200,
	}

	for i := 0; i < b.N; i++ {
		_, err := json.Marshal(msg)
		if err != nil {
			b.Error(err)
		}
	}
}

// 测试不同消息大小的 json 反序列化
func benchmarkJsonUnmarshalMessage(b *testing.B, contentLength int) {
	msg := &MMessage{
		MsgType:   1,
		HaveRead:  true,
		PageSize:  10,
		PageNum:   1,
		Content:   generateContent(contentLength),
		TimeStart: "2023-01-01 00:00:00",
		TimeEnd:   "2023-01-01 01:00:00",
		GroupID:   12345,
		From:      67890,
		To:        12345,
		CreateAt:  1672531200,
	}

	data, err := json.Marshal(msg)
	if err != nil {
		b.Error(err)
	}

	for i := 0; i < b.N; i++ {
		var m MMessage
		err = json.Unmarshal(data, &m)
		if err != nil {
			b.Error(err)
		}
	}
}

// 测试不同消息大小的 gob 序列化
func benchmarkGobMarshalMessage(b *testing.B, contentLength int) {
	msg := &MMessage{
		MsgType:   1,
		HaveRead:  true,
		PageSize:  10,
		PageNum:   1,
		Content:   generateContent(contentLength),
		TimeStart: "2023-01-01 00:00:00",
		TimeEnd:   "2023-01-01 01:00:00",
		GroupID:   12345,
		From:      67890,
		To:        12345,
		CreateAt:  1672531200,
	}

	var buf bytes.Buffer
	enc := gob.NewEncoder(&buf)

	for i := 0; i < b.N; i++ {
		buf.Reset()
		err := enc.Encode(msg)
		if err != nil {
			b.Error(err)
		}
	}
}

// 测试不同消息大小的 gob 反序列化
func benchmarkGobUnmarshalMessage(b *testing.B, contentLength int) {
	msg := &MMessage{
		MsgType:   1,
		HaveRead:  true,
		PageSize:  10,
		PageNum:   1,
		Content:   generateContent(contentLength),
		TimeStart: "2023-01-01 00:00:00",
		TimeEnd:   "2023-01-01 01:00:00",
		GroupID:   12345,
		From:      67890,
		To:        12345,
		CreateAt:  1672531200,
	}

	var buf bytes.Buffer
	enc := gob.NewEncoder(&buf)
	err := enc.Encode(msg)
	if err != nil {
		b.Error(err)
	}

	data := buf.Bytes()
	for i := 0; i < b.N; i++ {
		buf := bytes.NewBuffer(data)
		dec := gob.NewDecoder(buf)
		var m MMessage
		err := dec.Decode(&m)
		if err != nil {
			b.Error(err)
		}
	}
}

func benchmarkProtoUnmarshalMessage(b *testing.B, contentLength int) {
	msg := &Message{
		MsgType:   1,
		HaveRead:  true,
		PageSize:  10,
		PageNum:   1,
		Content:   generateContent(contentLength),
		TimeStart: "2023-01-01 00:00:00",
		TimeEnd:   "2023-01-01 01:00:00",
		GroupId:   12345,
		From:      67890,
		To:        12345,
		CreateAt:  1672531200,
	}

	data, err := proto.Marshal(msg)
	if err != nil {
		b.Error(err)
	}

	for i := 0; i < b.N; i++ {
		var m Message
		err = proto.Unmarshal(data, &m)
		if err != nil {
			b.Error(err)
		}
	}
}

// 测试不同消息大小的 gob 序列化
func benchmarkProtoMarshalMessage(b *testing.B, contentLength int) {
	msg := &Message{
		MsgType:   1,
		HaveRead:  true,
		PageSize:  10,
		PageNum:   1,
		Content:   generateContent(contentLength),
		TimeStart: "2023-01-01 00:00:00",
		TimeEnd:   "2023-01-01 01:00:00",
		GroupId:   12345,
		From:      67890,
		To:        12345,
		CreateAt:  1672531200,
	}

	for i := 0; i < b.N; i++ {
		buf, err := proto.Marshal(msg)
		if err != nil {
			b.Error(err)
		}
		_ = buf
	}
}

// 不同消息大小的基准测试入口
func BenchmarkMessage(b *testing.B) {
	contentLengths := []int{10, 100, 1000, 10000}
	for _, length := range contentLengths {
		slen := strconv.Itoa(length)

		b.Run("JsonMarshal-"+slen, func(subB *testing.B) {
			benchmarkJsonMarshalMessage(subB, length)
		})
		b.Run("JsonUnmarshal-"+slen, func(subB *testing.B) {
			benchmarkJsonUnmarshalMessage(subB, length)
		})
		b.Run("GobMarshal-"+slen, func(subB *testing.B) {
			benchmarkGobMarshalMessage(subB, length)
		})
		b.Run("GobUnmarshal-"+slen, func(subB *testing.B) {
			benchmarkGobUnmarshalMessage(subB, length)
		})
		b.Run("ProtoMarshal-"+slen, func(subB *testing.B) {
			benchmarkProtoMarshalMessage(subB, length)
		})
		b.Run("ProtoUnmarshal-"+slen, func(subB *testing.B) {
			benchmarkProtoUnmarshalMessage(subB, length)
		})
	}
}
