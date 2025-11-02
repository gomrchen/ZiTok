namespace go api.base

struct Base {
    1: optional i32 Code (go.tag="json:\"code,omitempty\"")
    2: optional string Msg (go.tag="json:\"msg,omitempty\"")
}
