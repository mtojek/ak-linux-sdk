ƽ̨��������������������˵�����£�

1����������һ��ƽ̨�Լ���env���������ļ�������Ϊenv.cfg��ÿ������������д��ʽΪ���ո� + name + �ո� + value�� �ο�envtool�µ�env_v330.cfg����env_v331.cfg�ļ���

2��envtool�µ�env_v330.cfg��env_v331.cfg�ļ����ֱ��Ӧak391xev330��ak391xev331оƬ��

3��Ȼ����shell��ִ��tr�������һ������ȫΪ0xff��env.img�����������񣬴�СΪ4K�Ļ�����������env.img��
tr '\000' '\377' < /dev/zero | dd of=./env.img bs=1024 count=4

4����linux�����£�ִ��mkenv_tools���Դ���./fw_setenv -s env.cfg�������յ�ƽ̨������������env.img��

5����linux�����£�ִ��mkenv_tools���Դ���./fw_printenv �鿴���ɵı�������env.img��������Ƿ���ȷ��