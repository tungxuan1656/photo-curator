# UI Copy (English / Vietnamese owner)

**Status:** Phase 1 contract · 2026-09-21

`ux-flows.md` owns where these strings appear and the screen state machine.
`review-rules.md` owns what each action means. This table is the only owner of
the user-facing labels below.

| Purpose/state | English (en) | Vietnamese (vi) |
|---|---|---|
| Cleanup entry | **Clean Up Photos** | **Dọn dẹp ảnh** |
| Album entry | **Build an Album** | **Tạo album** |
| Workspace title | **Review Photos** | **Xem lại ảnh** |
| Analysis | **Analyzing photos** | **Đang phân tích ảnh** |
| Resume | **Continue Review** | **Tiếp tục xem lại** |
| Review filter | **Needs Review** | **Cần xem lại** |
| Group label | **Similar Photos** | **Ảnh tương tự** |
| Album action | **Add to Album** | **Thêm vào album** |
| Album action | **Remove from Album** | **Xóa khỏi album** |
| Cleanup keep | **Keep** | **Giữ lại** |
| Cleanup stage | **Stage for Deletion** | **Đưa vào danh sách xóa** |
| Cleanup undo | **Unstage for Deletion** | **Bỏ khỏi danh sách xóa** |
| Suggestion note | **The app suggested this. You decide.** | **Ứng dụng đưa ra đề xuất. Bạn là người quyết định.** |
| Analysis unavailable | **Analysis unavailable** | **Không có dữ liệu phân tích** |
| Limited access | **Limited Photos Access** | **Quyền truy cập ảnh có giới hạn** |
| Full access needed | **Full Photos Access Needed** | **Cần quyền truy cập đầy đủ vào Ảnh** |
| Deletion confirmation title | **Delete these original photos?** | **Xóa những ảnh gốc này?** |
| Deletion confirmation body | **This action affects your Apple Photos library. You can’t undo it here.** | **Thao tác này ảnh hưởng đến thư viện Ảnh Apple. Bạn không thể hoàn tác tại đây.** |
| Access disclosure | **Full Photos access is required to delete originals. Limited access can review and stage photos, but can’t start deletion.** | **Cần quyền truy cập đầy đủ vào Ảnh để xóa ảnh gốc. Quyền truy cập có giới hạn cho phép xem lại và đưa ảnh vào danh sách, nhưng không thể bắt đầu xóa.** |
| iCloud disclosure | **Photos may sync with iCloud and remain in Recently Deleted. We can’t promise immediate recovered space.** | **Ảnh có thể đồng bộ với iCloud và vẫn nằm trong mục Đã xóa gần đây. Chúng tôi không thể hứa sẽ giải phóng dung lượng ngay lập tức.** |
| Deletion limited state | **Get Full Photos Access to Delete** | **Cấp quyền truy cập đầy đủ để xóa** |
| Deletion success | **Deletion complete** | **Đã xóa xong** |
| Deletion partial | **Some photos weren’t deleted** | **Một số ảnh chưa được xóa** |
| Deletion failed | **Couldn’t delete photos** | **Không thể xóa ảnh** |
| Album save | **Save Album** | **Lưu album** |
| Album saved | **Album Saved** | **Đã lưu album** |
| Save disclosure | **Saving an album does not change your cleanup choices.** | **Lưu album không thay đổi các lựa chọn dọn dẹp của bạn.** |
| Primary review action | **Review & Save** | **Xem lại và lưu** |
| Explicit suggestion choice | **Use Suggestion** | **Dùng đề xuất** |
| Keep user choice | **Keep My Choice** | **Giữ lựa chọn của tôi** |
| Empty review | **Nothing needs review** | **Không có gì cần xem lại** |
| Empty staged set | **Nothing staged for deletion** | **Chưa có ảnh nào được đưa vào danh sách xóa** |
| Safe failure | **Your choices are saved. Try again when you’re ready.** | **Các lựa chọn của bạn đã được lưu. Hãy thử lại khi bạn sẵn sàng.** |

Copy rules: say **Remove from Album** for membership, never use an album
exclusion label to imply library deletion; say **Stage for Deletion** only for
the reversible cleanup disposition; and always pair deletion confirmation with
the full-access and iCloud/Recently Deleted disclosure when applicable.

Accessibility labels must include the photo position, the independent album
and cleanup states, and the available action. Color and icons never carry a
state alone. All strings ship in English and Vietnamese; no new feature may
use an untranslated fallback string.
