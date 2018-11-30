M = 2**64-1
B = []
A = 0
c = 0

MAX = 5 * 1000 * 1000

def nextBlock():
    global M, A, c
    if c <= 1009827:
        x = (M-A) >> 20
    else:
        x = (M-A) >> 19
    brnew = max(x, (600000000000))
    B.append(brnew)
    A += brnew
    c +=1

for i in range(MAX +5):
    nextBlock()

def BR(n):
    return B[n] / 1E12


cumReward = 0

height = "block"
reward = "emission"
cumulative = "endAmount"

step = 5000

print("{}\t{}\t{}".format(height,reward,cumulative))
for i in range(MAX+1):
    cumReward += BR(i)
    if i % step == 0:
        print("{}\t{:.1f}\t{:.1f}".format(i,BR(i),cumReward))
