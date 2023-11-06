> typescript创建一个简单的EVM程序计数器
```typescript
class EVM {
  code: Uint8Array
  pc: number
  stack: number[]
  PUSH0 = 0x5f
  PUSH1 = 0x60
  PUSH32 = 0x7f
  POP = 0x50
  constructor(code: Uint8Array) {
    this.code = code // 初始化字节码，一个字节数组
    this.pc = 0 // 初始化程序计数器为0
    this.stack = [] // 堆栈初始为空
  }

  next_instruction(): number {
    const op = this.code[this.pc] // 获取当前指令
    this.pc += 1 // 递增
    return op
  }

  push(size: number): void {
    const data = this.code.slice(this.pc, this.pc + size) // 按照size从code中获取数据
    const value = this.bytesToInt(data) // 将字节数组转换为整数
    this.stack.push(value) // 压入堆栈
    this.pc += size // pc增加size单位
  }

  pop(): number {
    if (this.stack.length === 0) {
      throw new Error('Stack underflow')
    }
    return this.stack.pop()! // 弹出堆栈
  }

  bytesToInt(bytes: Uint8Array): number {
    let value = 0
    for (let i = 0; i < bytes.length; i++) {
      value = (value << 8) | bytes[i]
    }
    console.log(value)
    return value
  }

  run(): void {
    while (this.pc < this.code.length) {
      const op = this.next_instruction()

      if (op >= this.PUSH1 && op <= this.PUSH32) {
        const size = op - this.PUSH1 + 1
        this.push(size)
      } else if (op === this.PUSH0) {
        this.stack.push(0)
      } else if (op === this.POP) {
        this.pop()
      }
    }
  }
}

// test
const code = new Uint8Array([0x60, 0x01, 0x60, 0x01, 0x50])
const evm = new EVM(code)
evm.run()
console.log(evm.stack) // [1]

```