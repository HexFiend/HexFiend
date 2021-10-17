# Based on:
#   https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc776720(v=ws.10)
#   http://msdn.microsoft.com/en-us/windows/hardware/gg463080.aspx

ascii 8 Name
ascii 3 Extension
hex 1 Attributes
bytes 1 Reserved
hex 1 CreateTimeTenth
hex 2 CreateTime
hex 2 CreateDate
hex 2 LastAccessDate
bytes 2 FirstClusterHigh
hex 2 LastModifiedTime
hex 2 LastModifiedDate
uint16 StartingClusterNumber
uint32 FileSize
