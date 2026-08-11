/// Shared YYYY-MM-DD key used to store/query `schedules` and `tasks`
/// documents by day. Both admin (writer) and guard (reader) screens must
/// use this exact same function so a shift/task written for "today" is
/// always found by a query for "today" — never format the date ad-hoc
/// in one place and differently in another.
String dateKey(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-"
    "${d.month.toString().padLeft(2, '0')}-"
    "${d.day.toString().padLeft(2, '0')}";
