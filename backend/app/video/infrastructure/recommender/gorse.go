package recommender

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/yxrxy/videoHub/app/video/domain/model"
	repo "github.com/yxrxy/videoHub/app/video/domain/repository"
)

type GorseClient struct {
	endpoint string
	apiKey   string
	http     *http.Client
}

func NewGorseRecommender(endpoint, apiKey string) repo.Recommender {
	if endpoint == "" {
		return nil
	}
	return &GorseClient{
		endpoint: endpoint,
		apiKey:   apiKey,
		http:     &http.Client{Timeout: 2 * time.Second},
	}
}

type gorseItem struct {
	ItemId     string    `json:"ItemId"`
	IsHidden   bool      `json:"IsHidden"`
	Categories []string  `json:"Categories"`
	Timestamp  time.Time `json:"Timestamp"`
	Labels     []string  `json:"Labels"`
	Comment    string    `json:"Comment"`
}

type gorseFeedback struct {
	FeedbackType string `json:"FeedbackType"`
	UserId       string `json:"UserId"`
	ItemId       string `json:"ItemId"`
	Timestamp    string `json:"Timestamp"`
}

func (c *GorseClient) InsertItem(ctx context.Context, v *model.Video) error {
	if c == nil || v == nil {
		return nil
	}
	var labels []string
	if v.Tags != "" {
		// tags 以逗号分隔
		for _, s := range splitComma(v.Tags) {
			if s != "" {
				labels = append(labels, s)
			}
		}
	}
	it := gorseItem{
		ItemId:     fmt.Sprintf("%d", v.ID),
		IsHidden:   v.IsPrivate,
		Categories: nonEmptySlice(v.Category),
		Timestamp:  time.Now(),
		Labels:     labels,
		Comment:    v.Title,
	}
	body, _ := json.Marshal(it)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, fmt.Sprintf("%s/api/items", c.endpoint), bytes.NewReader(body))
	if err != nil {
		return nil
	}
	req.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	return nil
}

func (c *GorseClient) InsertFeedback(ctx context.Context, userID int64, videoID int64, feedbackType string, ts time.Time) error {
	if c == nil {
		return nil
	}
	payload := []gorseFeedback{{
		FeedbackType: feedbackType,
		UserId:       fmt.Sprintf("%d", userID),
		ItemId:       fmt.Sprintf("%d", videoID),
		Timestamp:    ts.UTC().Format(time.RFC3339),
	}}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, fmt.Sprintf("%s/api/feedback", c.endpoint), bytes.NewReader(body))
	if err != nil {
		return nil
	}
	req.Header.Set("Content-Type", "application/json")
	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	return nil
}

func (c *GorseClient) Recommend(ctx context.Context, userID int64, n int) ([]int64, error) {
	if c == nil {
		return nil, nil
	}
	url := fmt.Sprintf("%s/api/recommend/%d?n=%d", c.endpoint, userID, n)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	if c.apiKey != "" {
		req.Header.Set("X-API-Key", c.apiKey)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var ids []int64
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var arrStrings []string
	if err := json.Unmarshal(data, &arrStrings); err == nil && len(arrStrings) > 0 {
		for _, s := range arrStrings {
			if id, ok := parseInt64(s); ok {
				ids = append(ids, id)
			}
		}
		return ids, nil
	}
	type itemScore struct {
		Id     string  `json:"Id"`
		ItemId string  `json:"ItemId"`
		ItemID string  `json:"ItemID"`
		itemId string  `json:"itemId"`
		Score  float64 `json:"Score"`
	}
	var arrObj []itemScore
	if err := json.Unmarshal(data, &arrObj); err == nil && len(arrObj) > 0 {
		for _, it := range arrObj {
			cand := it.Id
			if cand == "" {
				cand = it.ItemId
			}
			if cand == "" {
				cand = it.ItemID
			}
			if cand == "" {
				cand = it.itemId
			}
			if id, ok := parseInt64(cand); ok {
				ids = append(ids, id)
			}
		}
		return ids, nil
	}
	return nil, nil
}

func splitComma(s string) []string {
	var res []string
	start := 0
	for i := 0; i <= len(s); i++ {
		if i == len(s) || s[i] == ',' {
			res = append(res, s[start:i])
			start = i + 1
		}
	}
	return res
}

func nonEmptySlice(s string) []string {
	if s == "" {
		return nil
	}
	return []string{s}
}

func parseInt64(s string) (int64, bool) {
	var n int64
	var sign int64 = 1
	i := 0
	if i < len(s) && (s[i] == '+' || s[i] == '-') {
		if s[i] == '-' {
			sign = -1
		}
		i++
	}
	for ; i < len(s); i++ {
		c := s[i]
		if c < '0' || c > '9' {
			return 0, false
		}
		n = n*10 + int64(c-'0')
	}
	return sign * n, true
}
