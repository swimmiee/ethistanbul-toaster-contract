import * as fs from "fs";
import * as jsonfile from "jsonfile";

export function updateConfig(
  filePath: string,
  key: string,
  value: any,
  isNewFile: boolean = false
): void {
  // JSON 파일 읽기
  jsonfile.readFile(filePath, (err: Error | null, data: Record<string,string>) => {
    if (!fs.existsSync(filePath)) {
      if (isNewFile) {
        // 새로운 JSON 데이터를 만듭니다.
        const data: { [key: string]: string } = {};
        data[key] = value;

        // 파일에 데이터 쓰기
        jsonfile.writeFile(
          filePath,
          data,
          { spaces: 2 },
          (err: Error | null) => {
            if (err) {
              console.error("파일에 쓰기 실패: " + err);
              return;
            }
            console.log("새로운 파일이 생성되고 데이터가 추가되었습니다.");
          }
        );
        return;
      } else {
        return;
      }
    }

    // 데이터 수정
    console.log(key, value)
    data[key] = value;

    // 수정된 데이터를 파일에 쓰기
    jsonfile.writeFile(filePath, data, { spaces: 2 }, (err: Error | null) => {
      if (err) {
        console.error("파일에 쓰기 실패: " + err);
        return;
      }
      console.log("파일이 성공적으로 업데이트되었습니다.");
    });
  });
}
