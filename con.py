#!/usr/bin/env python3
"""
16-bit Simple CPU Assembler / Converter

Instruction formats
-------------------
R type:
  [15:12] opcode [11:8] rd [7:4] rn1 [3:0] rn2
  ADD Rd, Rn1, Rn2
  SUB Rd, Rn1, Rn2

I type:
  [15:12] opcode [11:8] reg [7:0] imm/address
  MOV Rn, imm
  RD  Rn, address
  WR  Rn, address
  CMP Rn, imm

J type:
  [15:12] opcode [11:0] target
  JNE target

Opcode table (based on the supplied image)
  MOV = 0000
  RD  = 0001
  WR  = 0010
  ADD = 0011
  SUB = 0100
  CMP = 0101
  JNE = 0110
"""

from pathlib import Path
import re
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

OPCODES = {
    "MOV": 0x0,
    "RD":  0x1,
    "WR":  0x2,
    "ADD": 0x3,
    "SUB": 0x4,
    "CMP": 0x5,
    "JNE": 0x6,
}

R_TYPE = {"ADD", "SUB"}
I_TYPE = {"MOV", "RD", "WR", "CMP"}
J_TYPE = {"JNE"}


def strip_comment(line: str) -> str:
    # Supports ';' and '//' comments.
    line = line.split("//", 1)[0]
    line = line.split(";", 1)[0]
    return line.strip()


def parse_reg(token: str) -> int:
    token = token.strip().upper()
    m = re.fullmatch(r"R(\d+)", token)
    if not m:
        raise ValueError(f"レジスタ表記が不正です: {token}（例: R0, R15）")
    value = int(m.group(1))
    if not 0 <= value <= 15:
        raise ValueError(f"レジスタ範囲外です: {token}（R0～R15）")
    return value


def parse_num(token: str) -> int:
    token = token.strip().replace("_", "")
    if token.startswith("#"):
        token = token[1:].strip()

    # 0x12 / 0b1010 / decimal. Bare hex such as FF is also accepted.
    if re.fullmatch(r"0[xX][0-9a-fA-F]+", token):
        return int(token, 16)
    if re.fullmatch(r"0[bB][01]+", token):
        return int(token, 2)
    if re.fullmatch(r"\d+", token):
        return int(token, 10)
    if re.fullmatch(r"[0-9a-fA-F]+", token):
        return int(token, 16)

    raise ValueError(f"数値が不正です: {token}")


def split_instruction(line: str):
    clean = strip_comment(line)
    if not clean:
        return None, []

    parts = clean.split(None, 1)
    mnemonic = parts[0].upper()
    operands = []
    if len(parts) == 2:
        operands = [x.strip() for x in parts[1].split(",") if x.strip()]
    return mnemonic, operands


def assemble_line(line: str) -> int | None:
    mnemonic, ops = split_instruction(line)
    if mnemonic is None:
        return None

    if mnemonic not in OPCODES:
        raise ValueError(f"未定義命令です: {mnemonic}")

    opcode = OPCODES[mnemonic]

    if mnemonic in R_TYPE:
        if len(ops) != 3:
            raise ValueError(f"{mnemonic} は3オペランドです: {mnemonic} Rd, Rn1, Rn2")
        rd, rn1, rn2 = map(parse_reg, ops)
        return (opcode << 12) | (rd << 8) | (rn1 << 4) | rn2

    if mnemonic in I_TYPE:
        if len(ops) != 2:
            raise ValueError(f"{mnemonic} は2オペランドです: {mnemonic} Rn, imm/address")
        reg = parse_reg(ops[0])
        imm = parse_num(ops[1])
        if not 0 <= imm <= 0xFF:
            raise ValueError(f"{mnemonic} の即値/アドレスは8bitです: 0～255 (0x00～0xFF)")
        return (opcode << 12) | (reg << 8) | imm

    if mnemonic in J_TYPE:
        if len(ops) != 1:
            raise ValueError(f"{mnemonic} は1オペランドです: {mnemonic} target")
        target = parse_num(ops[0])
        if not 0 <= target <= 0xFFF:
            raise ValueError("JNE target は12bitです: 0～4095 (0x000～0xFFF)")
        return (opcode << 12) | target

    raise ValueError(f"形式未定義: {mnemonic}")


def assemble_text(text: str):
    results = []
    errors = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        if not strip_comment(raw):
            continue
        try:
            word = assemble_line(raw)
            if word is not None:
                results.append((lineno, raw.strip(), word))
        except ValueError as e:
            errors.append(f"{lineno}行目: {e}")
    return results, errors


def disassemble(word: int) -> str:
    opcode = (word >> 12) & 0xF
    reverse = {v: k for k, v in OPCODES.items()}
    mnemonic = reverse.get(opcode)
    if mnemonic is None:
        return f".WORD 0x{word:04X}"

    if mnemonic in R_TYPE:
        rd = (word >> 8) & 0xF
        rn1 = (word >> 4) & 0xF
        rn2 = word & 0xF
        return f"{mnemonic} R{rd}, R{rn1}, R{rn2}"

    if mnemonic in I_TYPE:
        reg = (word >> 8) & 0xF
        imm = word & 0xFF
        return f"{mnemonic} R{reg}, 0x{imm:02X}"

    if mnemonic in J_TYPE:
        target = word & 0xFFF
        return f"{mnemonic} 0x{target:03X}"

    return f".WORD 0x{word:04X}"


class ConverterApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("16bit 命令 → 16進数 変換TOOL")
        self.geometry("980x720")
        self.minsize(820, 600)

        self.reg_values = [f"R{i}" for i in range(16)]

        root = ttk.Frame(self, padding=12)
        root.pack(fill="both", expand=True)

        ttk.Label(root, text="16bit Simple CPU Assembler", font=("", 16, "bold")).pack(anchor="w")
        ttk.Label(
            root,
            text="ドロップリストで命令を作成して入力欄へ追加できます。入力欄は直接編集も可能です。"
        ).pack(anchor="w", pady=(3, 10))

        self.make_input_helper(root)
        self.make_main_area(root)

        # Ctrl+Enterでも変換可能
        self.bind("<Control-Return>", lambda event: self.convert())



    def make_input_helper(self, parent):
        helper = ttk.LabelFrame(parent, text="命令入力アシスト", padding=10)
        helper.pack(fill="x", pady=(0, 10))

        ttk.Label(helper, text="命令").grid(
            row=0, column=0, padx=4, pady=(0, 3), sticky="w"
        )

        self.op1_label = ttk.Label(helper, text="Operand 1")
        self.op2_label = ttk.Label(helper, text="Operand 2")
        self.op3_label = ttk.Label(helper, text="Operand 3")

        self.op1_label.grid(row=0, column=1, padx=4, pady=(0, 3), sticky="w")
        self.op2_label.grid(row=0, column=2, padx=4, pady=(0, 3), sticky="w")
        self.op3_label.grid(row=0, column=3, padx=4, pady=(0, 3), sticky="w")

        self.mnemonic_var = tk.StringVar(value="ADD")
        self.op1_var = tk.StringVar(value="R1")
        self.op2_var = tk.StringVar(value="R2")
        self.op3_var = tk.StringVar(value="R3")

        self.mnemonic_combo = ttk.Combobox(
            helper, textvariable=self.mnemonic_var,
            values=list(OPCODES.keys()), state="readonly", width=11
        )
        self.op1_combo = ttk.Combobox(helper, textvariable=self.op1_var, width=15)
        self.op2_combo = ttk.Combobox(helper, textvariable=self.op2_var, width=15)
        self.op3_combo = ttk.Combobox(helper, textvariable=self.op3_var, width=15)

        self.mnemonic_combo.grid(row=1, column=0, padx=4, pady=3)
        self.op1_combo.grid(row=1, column=1, padx=4, pady=3)
        self.op2_combo.grid(row=1, column=2, padx=4, pady=3)
        self.op3_combo.grid(row=1, column=3, padx=4, pady=3)

        ttk.Button(helper, text="↓ 入力欄へ追加", command=self.add_instruction).grid(
            row=1, column=4, padx=(12, 4), pady=3
        )

        self.format_label = ttk.Label(helper, text="")
        self.format_label.grid(row=2, column=0, columnspan=5, padx=4, pady=(5, 0), sticky="w")

        self.operand_help_label = ttk.Label(
            helper,
            text="",
            justify="left",
            wraplength=850
        )
        self.operand_help_label.grid(
            row=3, column=0, columnspan=5, padx=4, pady=(3, 0), sticky="w"
        )

        self.mnemonic_combo.bind("<<ComboboxSelected>>", self.update_operand_lists)

        # 操作ボタンはすべて入力アシストの下にまとめる
        actions = ttk.Frame(helper)
        actions.grid(row=4, column=0, columnspan=5, padx=4, pady=(10, 0), sticky="w")

        self.convert_button = ttk.Button(
            actions, text="▶ 16進数へ変換", command=self.convert
        )
        self.convert_button.pack(side="left", ipadx=10, ipady=3)

        ttk.Button(
            actions, text=".hex保存", command=self.save_hex
        ).pack(side="left", padx=(8, 0), ipady=3)

        ttk.Button(
            actions, text="カーソル行を削除", command=self.delete_current_line
        ).pack(side="left", padx=(8, 0), ipady=3)

        ttk.Button(
            actions, text="クリア", command=self.clear
        ).pack(side="left", padx=(8, 0), ipady=3)

        self.status = ttk.Label(actions, text="Ready")
        self.status.pack(side="left", padx=12)

        self.update_operand_lists()

    def make_main_area(self, parent):
        panes = ttk.Panedwindow(parent, orient="horizontal")
        panes.pack(fill="both", expand=True)

        left = ttk.Frame(panes, padding=4)
        right = ttk.Frame(panes, padding=4)
        panes.add(left, weight=1)
        panes.add(right, weight=1)

        ttk.Label(left, text="命令入力").pack(anchor="w")
        self.input_text = tk.Text(left, wrap="none", font=("Consolas", 11), undo=True)
        self.input_text.pack(fill="both", expand=True, pady=(4, 0))

        ttk.Label(right, text="16進数 (HEX)  ※「16進数へ変換」で更新").pack(anchor="w")
        self.output_text = tk.Text(right, wrap="none", font=("Consolas", 11))
        self.output_text.pack(fill="both", expand=True, pady=(4, 0))

    def update_operand_lists(self, event=None):
        ins = self.mnemonic_var.get().upper()

        if ins in R_TYPE:
            self.op1_label.config(text="Rd（出力）")
            self.op2_label.config(text="Rn1（入力1）")
            self.op3_label.config(text="Rn2（入力2）")

            self.set_combo(self.op1_combo, self.op1_var, self.reg_values, "R1", "readonly")
            self.set_combo(self.op2_combo, self.op2_var, self.reg_values, "R2", "readonly")
            self.set_combo(self.op3_combo, self.op3_var, self.reg_values, "R3", "readonly")
            self.format_label.config(text=f"{ins} Rd, Rn1, Rn2   例: {ins} R1, R2, R3")
            if ins == "ADD":
                help_text = (
                    "Operand 1 (Rd): 演算結果を書き込む宛先レジスタ    "
                    "Operand 2 (Rn1): 加算する第1入力レジスタ    "
                    "Operand 3 (Rn2): 加算する第2入力レジスタ\n"
                    "動作: Rd = Rn1 + Rn2"
                )
            else:
                help_text = (
                    "Operand 1 (Rd): 演算結果を書き込む宛先レジスタ    "
                    "Operand 2 (Rn1): 減算される値（第1入力）    "
                    "Operand 3 (Rn2): 引く値（第2入力）\n"
                    "動作: Rd = Rn1 - Rn2"
                )
            self.operand_help_label.config(text=help_text)

        elif ins in I_TYPE:
            if ins == "MOV":
                self.op1_label.config(text="Rn（書込先）")
                self.op2_label.config(text="imm（即値）")
            elif ins == "RD":
                self.op1_label.config(text="Rn（読出先）")
                self.op2_label.config(text="address（読出元）")
            elif ins == "WR":
                self.op1_label.config(text="Rn（書込データ）")
                self.op2_label.config(text="address（書込先）")
            elif ins == "CMP":
                self.op1_label.config(text="Rn（比較値）")
                self.op2_label.config(text="imm（比較対象）")
            self.op3_label.config(text="－")

            self.set_combo(self.op1_combo, self.op1_var, self.reg_values, "R1", "readonly")

            # Editable combobox: select a common value or type any decimal/hex value.
            imm_values = (
                [str(i) for i in range(16)] +
                [f"0x{i:02X}" for i in range(0, 256, 16)] +
                ["0xFF"]
            )
            self.set_combo(self.op2_combo, self.op2_var, imm_values, "0", "normal")
            self.set_combo(self.op3_combo, self.op3_var, [], "", "disabled")
            self.format_label.config(
                text=f"{ins} Rn, imm/address   8bit: 0～255 (0x00～0xFF)   ※直接入力可"
            )

            help_map = {
                "MOV": (
                    "Operand 1 (Rn): 即値を書き込む宛先レジスタ    "
                    "Operand 2 (imm): レジスタへ設定する8bit即値\n"
                    "動作: Rn = imm"
                ),
                "RD": (
                    "Operand 1 (Rn): 読み出したデータを格納するレジスタ    "
                    "Operand 2 (address): 読み出し元の8bitアドレス\n"
                    "動作: Rn = Memory[address]"
                ),
                "WR": (
                    "Operand 1 (Rn): 書き込むデータを持つレジスタ    "
                    "Operand 2 (address): 書き込み先の8bitアドレス\n"
                    "動作: Memory[address] = Rn"
                ),
                "CMP": (
                    "Operand 1 (Rn): 比較するレジスタ    "
                    "Operand 2 (imm): 比較対象となる8bit即値\n"
                    "動作: Rn と imm を比較し、分岐判定用の状態を更新"
                ),
            }
            self.operand_help_label.config(text=help_map.get(ins, ""))

        elif ins in J_TYPE:
            self.op1_label.config(text="target（分岐先）")
            self.op2_label.config(text="－")
            self.op3_label.config(text="－")

            targets = [f"0x{i:03X}" for i in range(0, 0x1000, 0x100)] + ["0xFFF"]
            self.set_combo(self.op1_combo, self.op1_var, targets, "0x000", "normal")
            self.set_combo(self.op2_combo, self.op2_var, [], "", "disabled")
            self.set_combo(self.op3_combo, self.op3_var, [], "", "disabled")
            self.format_label.config(
                text=f"{ins} target   12bit: 0～4095 (0x000～0xFFF)   ※直接入力可"
            )
            self.operand_help_label.config(
                text=(
                    "Operand 1 (target): 条件成立時にジャンプする12bitの分岐先アドレス\n"
                    "動作: 比較結果が Not Equal の場合に target へジャンプ"
                )
            )

    @staticmethod
    def set_combo(combo, var, values, default, state):
        combo.configure(values=values, state=state)
        var.set(default)

    def build_instruction(self):
        ins = self.mnemonic_var.get().upper()

        if ins in R_TYPE:
            return f"{ins} {self.op1_var.get()}, {self.op2_var.get()}, {self.op3_var.get()}"
        if ins in I_TYPE:
            return f"{ins} {self.op1_var.get()}, {self.op2_var.get()}"
        if ins in J_TYPE:
            return f"{ins} {self.op1_var.get()}"

        raise ValueError(f"未定義命令です: {ins}")

    def add_instruction(self):
        try:
            asm = self.build_instruction()
            word = assemble_line(asm)  # Validate before adding.
        except ValueError as e:
            messagebox.showerror("入力エラー", str(e))
            return

        # 現在カーソルがある行の「先頭」に命令を挿入する。
        # 例: カーソルが3行目のどこにあっても、新しい命令は3行目の先頭へ入り、
        # 元の3行目は1行下へ移動する。
        insert_index = self.input_text.index("insert linestart")
        self.input_text.insert(insert_index, asm + "\n")

        # 挿入した命令行を見える位置にし、カーソルは次の行の先頭へ。
        next_line = self.input_text.index(f"{insert_index} + 1 line")
        self.input_text.mark_set("insert", next_line)
        self.input_text.see(insert_index)
        self.input_text.focus_set()

        self.status.config(text=f"カーソル行へ追加: {asm} → 0x{word:04X}")

    def convert(self):
        results, errors = assemble_text(self.input_text.get("1.0", "end"))
        self.output_text.delete("1.0", "end")

        for _, asm, word in results:
            # 右側はHEXだけを1命令1行で表示。
            # .hex保存内容と同じ並びなので、そのまま確認・コピーしやすい。
            self.output_text.insert("end", f"{word:04X}\n")

        if errors:
            self.output_text.insert("end", "\n--- ERROR ---\n" + "\n".join(errors))
            self.status.config(text=f"{len(results)}命令変換 / {len(errors)}エラー")
        else:
            self.status.config(text=f"{len(results)}命令を変換しました")

    def save_hex(self):
        results, errors = assemble_text(self.input_text.get("1.0", "end"))

        if errors:
            messagebox.showerror("変換エラー", "\n".join(errors))
            return

        if not results:
            messagebox.showwarning("保存", "保存する命令がありません。")
            return

        path = filedialog.asksaveasfilename(
            defaultextension=".hex",
            filetypes=[
                ("HEX file", "*.hex"),
                ("Text file", "*.txt"),
                ("All files", "*.*")
            ]
        )
        if not path:
            return

        Path(path).write_text(
            "\n".join(f"{word:04X}" for _, _, word in results) + "\n",
            encoding="utf-8"
        )
        self.status.config(text=f"保存しました: {path}")

    def delete_current_line(self):
        """命令入力欄で現在カーソルがある1行を削除する。"""
        self.input_text.focus_set()
        line_no = int(self.input_text.index("insert").split(".")[0])

        start = f"{line_no}.0"
        # 最終行以外は改行も含めて削除。最終行では行本体を削除。
        if self.input_text.compare(f"{line_no}.0", "<", "end-1c"):
            end = f"{line_no + 1}.0"
        else:
            end = "end-1c"

        self.input_text.delete(start, end)

        # 削除後も同じ行位置にカーソルを置く。
        target = self.input_text.index(f"{min(line_no, int(self.input_text.index('end-1c').split('.')[0]))}.0")
        self.input_text.mark_set("insert", target)
        self.input_text.see(target)
        self.status.config(text=f"{line_no}行目を削除しました")

    def clear(self):
        self.input_text.delete("1.0", "end")
        self.output_text.delete("1.0", "end")
        self.status.config(text="Ready")


if __name__ == "__main__":
    app = ConverterApp()
    app.mainloop()
