# GUI Verification Protocol (tkinter)

WSL2では tkinter の実機確認不可。以下のプロトコルで補完する (karo+gunshi+ashigaru 関与):

1. **gui_review_required: true** (task YAML): 軍師が実装前に frame 設計をレビュー
2. **manual_verification_required: true** (task YAML): 殿の実機確認をダッシュボード [action] に登録
3. **py_compile 静的検証** (ashigaru): import エラー・文法エラーを事前検出
4. **実機確認依頼** (dashboard): karo が [action] タグで殿にWindowsでの動作確認を依頼

※ gui_review_required=true のタスクは完了後も karo がダッシュボードから手動削除するまで残す
