const PUSH0 = 0x5f
const PUSH1 = 0x60
const PUSH32 = 0x7f
const POP = 0x50
const ADD = 0x01
const MUL = 0x02
const SUB = 0x03
const DIV = 0x04
const MOD = 0x06
const LT = 0x10
const GT = 0x11
const EQ = 0x14
const AND = 0x16
const OR = 0x17
const XOR = 0x18
const NOT = 0x19
const SHL = 0x1b
const SHR = 0x1c
const MSTORE = 0x52
const MSTORE8 = 0x53
class EVM {
  private code: Uint8Array // 每个 EVM 字节码指令占用一个字节（8 比特），EVM 字节码的指令范围是从 0x00 到 0xFF，共 256 个不同的指令
  private counter: number // 计数器
  private stack: number[] //堆栈
  private memory: Uint8Array = new Uint8Array() // 内存

  constructor(code: Uint8Array) {
    this.code = code
    this.counter = 0
    this.stack = []
  }

  nextInstruction(): number {
    const op = this.code[this.counter]
    this.counter += 1
    return op
  }

  push(size: number): void {
    const data = this.code.slice(this.counter, this.counter + size) // 在这个例子里首次进来时计数器已经来到了1
    const value = parseInt([...data].map(byte => byte.toString(16).padStart(2, '0')).join(''), 16)
    this.stack.push(value)
    this.counter += size
  }

  pop(): void {
    if (this.stack.length === 0) throw new Error('Stack underflow')
    this.stack.pop()
  }

  add(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const addResult = (item1 + item2) % 2 ** 256
    this.stack.push(addResult)
  }

  mul(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const mulResult = (item1 * item2) % 2 ** 256
    this.stack.push(mulResult)
  }
  sub(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const subResult = (item1 - item2) % 2 ** 256
    this.stack.push(subResult)
  }
  div(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    if (item2 === 0) {
      this.stack.push(0)
      return
    }
    const divResult = (item1 / item2) % 2 ** 256
    this.stack.push(divResult)
  }
  mod(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const modResult = item2 !== 0 ? (item1 % item2) % 2 ** 256 : 0
    this.stack.push(modResult)
  }
  lt(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const ltResult = item1 < item2 ? 1 : 0
    this.stack.push(ltResult)
  }
  gt(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const gtResult = item1 > item2 ? 1 : 0
    this.stack.push(gtResult)
  }
  eq(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const eqResult = item2 === item1 ? 1 : 0
    this.stack.push(eqResult)
  }

  and(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const andResult = item2 & item1
    this.stack.push(andResult)
  }
  or(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const orResult = item2 | item1
    this.stack.push(orResult)
  }
  xor(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const xorResult = item2 ^ item1
    this.stack.push(xorResult)
  }
  not(): void {
    if (this.stack.length < 1) throw new Error('Stack underflow')
    const item = this.stack.pop()!
    const notResult = ~item % 2 ** 256
    this.stack.push(notResult)
  }
  shl(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const shlResult = item1 << item2
    this.stack.push(shlResult)
  }
  shr(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const item1 = this.stack.pop()!
    const item2 = this.stack.pop()!
    const shrResult = item1 >> item2
    this.stack.push(shrResult)
  }

  mstore(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const offset = this.stack.pop()! // 获取内存偏移量
    const value = this.stack.pop()! // 获取内存值
    while (this.memory.length < offset + 32) {
      this.memory = new Uint8Array([...this.memory, 0]) // 内存不足时，扩容
    }
    const valueBytes: Uint8Array = new Uint8Array(new Array(32).fill(0)) // 创建 32 字节的 Uint8Array
    const binaryString = value.toString(2).padStart(256, '0') // 将 value 转换为 256 位的二进制字符串
    for (let i = 0; i < 32; i++) {
      const byteString = binaryString.slice(i * 8, (i + 1) * 8) // 将二进制字符串按字节分割并写入 Uint8Array
      const byteValue = parseInt(byteString, 2) // 将二进制字符串转换为十进制
      valueBytes[i] = byteValue // 将十进制写入 Uint8Array
    }
    this.memory.set(valueBytes, offset) // 将 Uint8Array 写入内存
  }
  mstore8(): void {
    if (this.stack.length < 2) throw new Error('Stack underflow')
    const offset = this.stack.pop()! // 获取内存偏移量
    const value = this.stack.pop()! // 获取内存值
    while (this.memory.length < offset + 32) {
      this.memory = new Uint8Array([...this.memory, 0]) // 内存不足时，扩容
    }
    this.memory.set([value & 0xff], offset) // 取最低有效字节
  }

  run(): void {
    while (this.counter < this.code.length) {
      const op = this.nextInstruction()
      // 如果遇到PUSH操作，则执行
      if (op >= PUSH1 && op <= PUSH32) {
        const size = op - PUSH1 + 1 // PUSH(size)
        this.push(size)
      } else if (op === PUSH0) {
        this.stack.push(0)
      } else if (op === POP) {
        this.pop()
      } else if (op === ADD) {
        this.add()
      } else if (op === MUL) {
        this.mul()
      } else if (op === SUB) {
        this.sub()
      } else if (op === DIV) {
        this.div()
      } else if (op === MOD) {
        this.mod()
      } else if (op === LT) {
        this.lt()
      } else if (op === GT) {
        this.gt()
      } else if (op === EQ) {
        this.eq()
      } else if (op === AND) {
        this.and()
      } else if (op === OR) {
        this.or()
      } else if (op === XOR) {
        this.xor()
      } else if (op === NOT) {
        this.not()
      } else if (op === SHL) {
        this.shl()
      } else if (op === SHR) {
        this.shr()
      } else if (op === MSTORE) {
        this.mstore()
      } else if (op === MSTORE8) {
        this.mstore8()
      }
    }
    console.log('stack', this.stack) // 测试堆栈
    console.log(this.memory.subarray(0x20, 0x40)) // 测试内存));
  }
}

// 示例用法
const testPush = () => {
  // code = b"\x60\x02\x60\x03\x01"
  const code = new Uint8Array([0x60, 0x01, 0x60, 0x01])
  const evm = new EVM(code)
  evm.run() // 输出:  [1, 1]
}
const testPop = () => {
  const code = new Uint8Array([0x60, 0x01, 0x50])
  const evm = new EVM(code)
  evm.run() // 输出:  []
}
const testAdd = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x03, 0x01])
  const evm = new EVM(code)
  evm.run() // 输出:  [5]
}
const testMul = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x03, 0x02])
  const evm = new EVM(code)
  evm.run() // 输出:  [6]
}
const testSub = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x03, 0x03]) // 3 - 2
  const evm = new EVM(code)
  evm.run() // 输出:  [1]
}
const testDiv = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x04]) // 6 / 2
  const evm = new EVM(code)
  evm.run() // 输出:  [3]
}
const testMod = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x06]) // 6 % 2
  const evm = new EVM(code)
  evm.run() // 输出:  [0]
}
const testLt = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x10]) // 6 < 2
  const evm = new EVM(code)
  evm.run() // 输出:  [0]
}
const testGt = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x11]) // 6 > 2
  const evm = new EVM(code)
  evm.run() // 输出:  [1]
}
const testEq = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x14]) // 6 == 2
  const evm = new EVM(code)
  evm.run() // 输出:  [0]
}
const testAnd = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x16]) // 6 & 2 ->    110 & 010 = 010 = 2
  const evm = new EVM(code)
  evm.run() // 输出:  [2]
}
const testOr = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x17]) // 6 | 2 ->    110 | 010 = 110 = 6
  const evm = new EVM(code)
  evm.run() // 输出:  [6]
}
const testXor = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x18]) // 6 ^ 2 ->    110 ^ 010 = 100 = 4
  const evm = new EVM(code)
  evm.run() // 输出:  [4]
}
const testNot = () => {
  const code = new Uint8Array([0x60, 0x02, 0x19]) // ~2 ->    ～10 -> 00000000000000000000000000000010 -> 11111111111111111111111111111101 -> 10 -> 11 -> -3  (对于正整数, ～x = -x - 1;对于负整数, ～x = -x + 1)
  const evm = new EVM(code)
  evm.run() // 输出:  [-3]
}
const testShl = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x1b]) // 6 << 2 ->    110 << 2 = 11000 = 24
  const evm = new EVM(code)
  evm.run() // 输出:  [24]
}
const testShr = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x06, 0x1c]) // 6 >> 2 ->    110 >> 2 = 001 = 1
  const evm = new EVM(code)
  evm.run() // 输出:  [1]
}
const testMstore = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x20, 0x52]) // mstore(32, 2)
  const evm = new EVM(code)
  evm.run() // 输出: [...,2] 前面为 31 位 0
}
const testMstore8 = () => {
  const code = new Uint8Array([0x60, 0x02, 0x60, 0x20, 0x53]) // mstore8(32, 2)
  const evm = new EVM(code)
  evm.run()
}

testPush()
testPop()
testAdd()
testMul()
testSub()
testDiv()
testMod()
testLt()
testGt()
testEq()
testAnd()
testOr()
testXor()
testNot()
testShl()
testShr()
testMstore()
testMstore8()
