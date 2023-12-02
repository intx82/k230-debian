	.text
	.globl	_start

write:
	li	a7, 64 # __NR_write
	ecall
	ret

ppoll:
	li	a7, 73 # __NR_ppoll
	ecall
	ret

pause:
	mv	a0, zero # ufd = NULL
	mv	a1, zero # nfds = 0
	mv	a2, zero # ts = NULL
	mv	a3, zero # sigset = NULL
	mv	a4, zero # sigsetsize = 0
	j	ppoll

_start:
	li	a0, 1 # fd = fileno(stdout)
	lla	a1, message
	lla	a2, message_end
	sub	a2, a2, a1
	jal	write
	auipc	ra, 0
	j	pause

message:
	.ascii	"\n"
	.ascii	"Hello world!\n"
	.ascii	"\n"
	.ascii	"The system has successfully booted.\n"
	.ascii	"But it seems nothing is installed on the root filesystem.\n"
	.ascii	"\n"
	.ascii	"It is safe to power the system off now.\n"
message_end:
